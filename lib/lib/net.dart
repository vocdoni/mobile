import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dvote/dvote.dart';
import 'package:vocdoni/app-config.dart';
import 'package:vocdoni/lib/logger.dart';
// import 'package:vocdoni/constants/settings.dart';

class AppNetworking {
  static GatewayPool _gwPool;
  static Future<void> _discoveryFuture;

  static GatewayPool get pool => _gwPool;

  static bool isReady() {
    return dvoteIsReady() && web3IsReady();
  }

  static bool dvoteIsReady() {
    return pool is GatewayPool &&
        pool.current is Gateway &&
        pool.current.dvote is DVoteGateway;
  }

  static bool web3IsReady() {
    return pool.current.web3.isReady;
  }

  /// Fetch the list of gateways from a well-known URI and initialize a new Gateway Pool from scratch
  static Future<void> init({bool forceReload = false}) {
    if (!forceReload) {
      // Skip reload if already doing so
      if (_discoveryFuture is Future) {
        return _discoveryFuture;
      } else if (isReady()) {
        return Future.value();
      }
    }

    // Fetch gateways
    _discoveryFuture = GatewayPool.discover(AppConfig.NETWORK_ID,
            bootnodeUri: AppConfig.bootnodesUrl,
            ensDomainSuffix: AppConfig.ensDomainSuffix)
        .then((gwPool) {
      if (gwPool is! GatewayPool)
        throw Exception("Could not initialize a pool of gateways");

      _gwPool = gwPool;

      logger.log("[App] GW Pool ready");
      logger.log("- DVote Gateway: ${pool.current?.dvote?.uri}");
      logger.log("- Web3 Gateway: ${pool.current?.web3?.uri}");
      _discoveryFuture = null;
    }).catchError((err) {
      logger.log("[App] GW discovery failed: $err");

      if (err is SocketException) {
        logger.log("[App] The network seems to be down");
      }
      _discoveryFuture = null;
    });

    return _discoveryFuture;
  }

  /// Use pre-existing bootnode's data to initialize a Gateway Pool
  static Future<void> useFromGatewayInfo(BootNodeGateways gwInfo,
      {bool forceReload = false}) {
    if (!forceReload) {
      // Skip reload if already doing so
      if (_discoveryFuture is Future) {
        return _discoveryFuture;
      } else if (dvoteIsReady()) {
        return Future.value();
      }
    }

    _discoveryFuture = discoverGatewaysFromBootnodeInfo(gwInfo,
            networkId: AppConfig.NETWORK_ID,
            ensDomainSuffix: AppConfig.ensDomainSuffix)
        .then((gateways) {
      if (gateways is! List || gateways.length == 0)
        throw Exception("There are no active gateways");

      // OK
      _gwPool = GatewayPool(gateways, AppConfig.NETWORK_ID,
          bootnodeUri: AppConfig.bootnodesUrl,
          ensDomainSuffix: AppConfig.ensDomainSuffix);

      logger.log("[App] GW Pool ready");
      logger.log("- DVote Gateway: ${pool.current.dvote.uri}");
      logger.log("- Web3 Gateway: ${pool.current.web3.uri}");
      _discoveryFuture = null;
    }).catchError((err) {
      logger.log("[App] GW discovery failed: $err");
      _discoveryFuture = null;
    });

    return _discoveryFuture;
  }

  /// Manually set the gateway pool
  static void setGateways(List<Gateway> gateways, String networkId) {
    if (gateways is! List || gateways.length == 0)
      throw Exception("Empty list");

    _gwPool = GatewayPool(gateways, networkId,
        ensDomainSuffix: AppConfig.ensDomainSuffix);
  }
}

/*
 * Get a URI providing the given string content
 */
String uriFromContent(String content) {
  return new Uri.dataFromString(content,
          mimeType: 'text/html', encoding: Encoding.getByName('utf-8'))
      .toString();
}
