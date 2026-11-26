import 'package:dio/dio.dart';
import 'package:hiddify/core/http_client/dio_http_client.dart';
import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/core/model/region.dart';
import 'package:hiddify/features/app_based_routing/model/per_app_proxy_mode.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum AutoSelectionResult { success, failure, notFound }

/// perso : applis qui ne passent jamais par le VPN (seules celles installées sont prises en compte).
const chinaDirectApps = <String>{
  'com.eg.android.AlipayGphone', // Alipay
  'hk.alipay.wallet', // AlipayHK
  'com.tencent.mm', // WeChat
  'com.tencent.mobileqq', // QQ
  'com.tencent.wework', // WeCom
  'com.taobao.taobao', // Taobao
  'com.taobao.litetao', // Taobao Lite
  'com.tmall.wireless', // Tmall
  'com.taobao.idlefish', // Xianyu
  'com.cainiao.wireless', // Cainiao
  'com.taobao.trip', // Fliggy
  'com.xunmeng.pinduoduo', // Pinduoduo
  'com.larus.nova', // Doubao
  'com.aitutor.hippo', // 豆包爱学
  'com.sinovatech.unicom.ui', // China Unicom
  'com.ss.android.ugc.aweme', // Douyin
  'com.ss.android.lark', // Feishu
  'org.kde.kdeconnect_tp', // KDE Connect
  'com.jingdong.app.mall', // JD
  'com.sankuai.meituan', // Meituan
  'com.sankuai.meituan.takeoutnew', // Meituan Waimai
  'me.ele', // Ele.me
  'com.dianping.v1', // Dianping
  'com.sdu.didi.psnger', // DiDi
  'com.xingin.xhs', // Xiaohongshu
  'com.autonavi.minimap', // Amap
  'com.baidu.BaiduMap', // Baidu Maps
  'com.alibaba.android.rimet', // DingTalk
  'com.unionpay', // UnionPay
  'com.MobileTicket', // 12306
  'tv.danmaku.bili', // Bilibili
  'com.netease.cloudmusic', // NetEase Music
  'com.tencent.qqmusic', // QQ Music
  'com.sina.weibo', // Weibo
  'com.smile.gifmaker', // Kuaishou
  'com.tencent.map', // Tencent Maps
  'com.icbc', // ICBC
  'cmb.pb', // China Merchants Bank
  'com.chinamworld.main', // CCB
  'com.android.bankabc', // ABC
  'com.chinamworld.bocmbci', // BOC
};

abstract interface class AutoSelectionRepository {
  Future<(Set<String>?, AutoSelectionResult)> getByAppProxyMode({required AppProxyMode mode, required Region region});
}

class AutoSelectionRepositoryImpl with AppLogger implements AutoSelectionRepository {
  AutoSelectionRepositoryImpl({required Ref ref}) : _ref = ref;
  final Ref _ref;
  static const _baseUrl = 'https://raw.githubusercontent.com/hiddify/Android-GFW-Apps/refs/heads/master/';

  @override
  Future<(Set<String>?, AutoSelectionResult)> getByAppProxyMode({
    required AppProxyMode mode,
    required Region region,
  }) async {
    // perso : en Chine + mode Exclure, la liste distante (direct_cn) est vide et GitHub est souvent
    // bloqué : on utilise la liste intégrée des applis qui passent en direct.
    if (region == Region.cn && mode == AppProxyMode.exclude) {
      return (chinaDirectApps, AutoSelectionResult.success);
    }
    try {
      final rs = await _getHttp().get(_genUrl(mode, region));
      if (rs.statusCode == 200) {
        final list = _parseToListOfString(rs.data);
        // some regions have an empty file (direct_cn, proxy_ru), which means no list
        if (list.isEmpty) return (null, AutoSelectionResult.notFound);
        return (list, AutoSelectionResult.success);
      }
      loggy.error("Auto selection failed. status code : ${rs.statusCode}");
      return (null, AutoSelectionResult.failure);
    } on DioException catch (e, st) {
      if (e.response?.statusCode == 404) {
        loggy.error("Auto selection region not found. region : ${region.name}", e, st);
        return (null, AutoSelectionResult.notFound);
      } else {
        loggy.error("Failed to fetch auto selection", e, st);
        return (null, AutoSelectionResult.failure);
      }
    } catch (e, st) {
      loggy.error("Failed to fetch auto selection with unexpected error", e, st);
      return (null, AutoSelectionResult.failure);
    }
  }

  String _genUrl(AppProxyMode mode, Region region) => switch (mode) {
    AppProxyMode.include => '${_baseUrl}proxy_${region.name}',
    AppProxyMode.exclude => '${_baseUrl}direct_${region.name}',
  };

  Set<String> _parseToListOfString(dynamic data) =>
      data.toString().split('\n').map((e) => e.trim()).where((element) => element.isNotEmpty).toSet();

  DioHttpClient _getHttp() => _ref.read(httpClientProvider);
}
