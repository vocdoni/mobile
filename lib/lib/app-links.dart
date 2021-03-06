import 'package:convert/convert.dart';
import 'package:dvote/dvote.dart';
import 'package:dvote/models/build/dart/client-store/recovery.pb.dart';
import 'package:dvote_common/widgets/overlays.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:vocdoni/app-config.dart';
import 'package:vocdoni/data-models/entity.dart';
import 'package:vocdoni/data-models/process.dart';
import 'package:vocdoni/lib/errors.dart';
import 'package:vocdoni/lib/globals.dart';
import 'package:vocdoni/lib/i18n.dart';
import 'package:vocdoni/lib/logger.dart';
import 'package:vocdoni/lib/net.dart';
import 'package:vocdoni/views/feed-post-page.dart';
import 'package:vocdoni/views/poll-page.dart';
import 'package:vocdoni/views/recovery/recovery-verification-input.dart';
import 'package:vocdoni/views/register-validation-page.dart';

const entityRegex = r"^(0x)?[a-zA-Z0-9]{40,64}$";
bool init = false;

// /////////////////////////////////////////////////////////////////////////////
// / MAIN
// /////////////////////////////////////////////////////////////////////////////

Future handleIncomingLink(Uri newLink, BuildContext ctx) async {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> indicator;
  OverlaySupportEntry overlayIndicator;
  overlayIndicator = showLoadingOverlay(getText(ctx, "main.loading") + "...");

  try {
    final uriSegments = extractLinkSegments(newLink);

    // If link requires networking, ensure networking is set up
    if (requiresNetworking(uriSegments[0])) {
      int retries = 20; // try for 10 seconds
      while (!AppNetworking.dvoteIsReady()) {
        if (retries == 0) throw LinkingError("Networking unavailable");
        retries--;
        await Future.delayed(Duration(milliseconds: 500));
      }
    }

    // Just open the app, do nothing
    if (uriSegments == null || uriSegments.length == 0) return;

    switch (uriSegments[0]) {
      case "entities":
        await handleEntityLink(
          uriSegments,
          context: ctx,
        );
        break;
      case "validation":
        await handleValidationLink(uriSegments, context: ctx);
        break;
      case "posts":
        await handleNewsLink(uriSegments, context: ctx);
        break;
      case "processes":
        await handleProcessLink(uriSegments, context: ctx);
        break;
      case "recovery":
        await handleRecoveryLink(uriSegments, context: ctx);
        break;
      // case "signature":
      //   await showSignatureScreen(
      //       payload: newLink.queryParameters["payload"],
      //       returnUri: newLink.queryParameters["returnUri"],
      //       context: ctx);
      //   break;
      default:
        if (indicator != null) indicator.close();
        if (overlayIndicator != null) overlayIndicator.dismiss(animate: true);
        throw LinkingError("Invalid path");
    }
    if (overlayIndicator != null) overlayIndicator.dismiss(animate: true);
    if (indicator != null) indicator.close();
  } catch (err) {
    if (overlayIndicator != null) overlayIndicator.dismiss(animate: true);
    if (indicator != null) indicator.close();
    logger.log("ERR: $err");
    throw err;
  }
}

bool requiresNetworking(String path) {
  if (path.contains("recovery")) return false;
  return true;
}

// /////////////////////////////////////////////////////////////////////////////
// / HANDLERS
// /////////////////////////////////////////////////////////////////////////////

Future handleEntityLink(
  List<String> linkSegments, {
  @required BuildContext context,
}) async {
  final paramSegments = linkSegments.skip(1).toList();
  // paramSegments => [ "0x462fc85288f9b204d5a146901b2b6a148bddf0ba1a2fb5c87fb33ff22891fb46" ]

  String entityId;
  if (paramSegments[0] is String &&
      RegExp(entityRegex).hasMatch(paramSegments[0])) {
    entityId = paramSegments[0];
  }

  if (entityId is! String) {
    throw LinkingError("Invalid entityId");
  }

  EntityReference entityRef = EntityReference();
  entityRef.entityId = entityId;

  final entityModel = EntityModel(entityRef);

  try {
    // fetch metadata from the reference. The view will fetch the rest.
    await entityModel.refreshMetadata();

    final currentAccount = Globals.appState.currentAccount;
    if (currentAccount == null) throw Exception("Internal error");

    // subscribe if not already
    await currentAccount.subscribe(entityModel);
    // Set notifications on if not already subscribed
    if (!entityModel.hasNotificationsEnabled()) {
      await entityModel.enableNotifications();
    }
    await Globals.accountPool.writeToStorage();
    Navigator.pushNamed(Globals.navigatorKey.currentContext, "/entity",
        arguments: entityModel);
  } catch (err) {
    throw Exception(getText(context, "error.couldNotFetchTheEntityDetails"));
  }
}

Future handleNewsLink(
  List<String> linkSegments, {
  @required BuildContext context,
}) async {
  final paramSegments = linkSegments.skip(1).toList();
  // paramSegments => [ "0x-entity-id", "0x-post-id" ]

  final entityId = paramSegments[0];
  final postId = paramSegments[1];

  if (entityId is! String || !RegExp(entityRegex).hasMatch(entityId))
    throw LinkingError("Invalid entityId");

  final entityModel = Globals.entityPool.value.firstWhere(
    (entityModel) => entityModel.reference.entityId == entityId,
    orElse: () {
      // If we don't have it, initialize it locally
      EntityReference entityRef = EntityReference();
      entityRef.entityId = entityId;

      return EntityModel(entityRef);
    },
  );

  try {
    final currentAccount = Globals.appState.currentAccount;
    if (currentAccount == null) throw Exception("Internal error");

    // fetch metadata from the reference. The view will fetch the rest.
    await entityModel.refreshMetadata();
    await entityModel.refreshFeed();

    // Navigate
    final post = entityModel.feed.value.items
        .firstWhere((post) => post.id == postId, orElse: () => null);
    if (post == null) throw Exception();
    Navigator.of(context).pushNamed("/entity/feed/post",
        arguments: FeedPostArgs(entity: entityModel, post: post));
  } catch (err) {
    // showMessage("Could not fetch the entity details",
    //     context: context, purpose: Purpose.DANGER);
    throw Exception(getText(context, "error.couldNotFindThePost"));
  }
}

Future handleProcessLink(
  List<String> linkSegments, {
  @required BuildContext context,
}) async {
  final paramSegments = linkSegments.skip(1).toList();
  // paramSegments => [ "0x-entity-id", "0x-process-id" ]

  final entityId = paramSegments[0];
  final processId = paramSegments[1];

  if (entityId is! String || !RegExp(entityRegex).hasMatch(entityId))
    throw LinkingError("Invalid entityId");

  final entityModel = Globals.entityPool.value.firstWhere(
    (entityModel) => entityModel.reference.entityId == entityId,
    orElse: () {
      // If we don't have it, initialize it locally
      EntityReference entityRef = EntityReference();
      entityRef.entityId = entityId;

      return EntityModel(entityRef);
    },
  );

  try {
    final currentAccount = Globals.appState.currentAccount;
    if (currentAccount == null) throw Exception("Internal error");

    // fetch metadata from the reference. The view will fetch the rest.
    await entityModel.refreshMetadata();

    final processModel = entityModel.processes.value.firstWhere(
      (processModel) => processModel.processId == processId,
      orElse: () => ProcessModel(processId, entityId),
    );
    if (processModel.metadata.hasValue) {
      // Detached refresh so we can navigate now
      processModel.refresh().catchError((err) => logger.log(err));
    } else {
      // Await refresh so pollPage doesn't return
      await processModel.refresh();
    }

    // Navigate
    Navigator.pushNamed(
        Globals.navigatorKey.currentContext, "/entity/participation/poll",
        arguments: PollPageArgs(entity: entityModel, process: processModel));
  } catch (err) {
    // showMessage("Could not fetch the entity details",
    //     context: context, purpose: Purpose.DANGER);
    logger.log(err);
    throw Exception(getText(context, "error.couldNotFetchTheProcessDetails"));
  }
}

Future handleRecoveryLink(
  List<String> linkSegments, {
  @required BuildContext context,
}) async {
  if (linkSegments.length < 3 ||
      !(linkSegments[0] is String) ||
      !(linkSegments[1] is String) ||
      !(linkSegments[2] is String) ||
      !(linkSegments[3] is String)) {
    throw LinkingError("Invalid validation link");
  }

  try {
    // Decode & deserialize protobuf recovery model
    final recoveryBytes = hex.decode(linkSegments.sublist(3).join());
    AccountRecovery recoveryModel = AccountRecovery.fromBuffer(recoveryBytes);

    // Navigate
    Navigator.pushNamed(Globals.navigatorKey.currentContext, "/recovery",
        arguments: RecoveryVerificationArgs(
            accountName: Uri.decodeComponent(linkSegments[1]),
            date: linkSegments[2],
            recoveryModel: recoveryModel));
  } catch (err) {
    logger.log(err);
    throw Exception(getText(context, "error.invalidUrl") + " $err");
  }
}

Future handleValidationLink(
  List<String> linkSegments, {
  @required BuildContext context,
}) async {
  final paramSegments = linkSegments.skip(1).toList();
  // paramSegments => [ "0x462fc85288f9b204d5a146901b2b6a148bddf0ba1a2fb5c87fb33ff22891fb46", "token-1234" ]

  if (paramSegments.length < 2 ||
      !(paramSegments[0] is String) ||
      !(paramSegments[1] is String)) {
    throw LinkingError("Invalid validation link");
  } else if (!RegExp(entityRegex).hasMatch(paramSegments[0]) ||
      !RegExp(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
          .hasMatch(paramSegments[1])) {
    throw LinkingError("Invalid validation link");
  }

  final entityId = paramSegments[0];
  final validationToken = paramSegments[1];

  EntityReference entityRef = EntityReference();
  entityRef.entityId = entityId;

  final entityModel = EntityModel(entityRef);

  try {
    // fetch metadata from the reference. The view will fetch the rest.
    await entityModel.refreshMetadata();

    final currentAccount = Globals.appState.currentAccount;
    if (currentAccount == null) throw Exception("Internal error");

    // subscribe if not already
    if (!currentAccount.isSubscribed(entityRef)) {
      await currentAccount.subscribe(entityModel);
      // Set notifications on if not already subscribed
      if (!entityModel.hasNotificationsEnabled()) {
        await entityModel.enableNotifications();
      }
    }

    final name = entityModel.metadata.value?.name["default"];
    if (!(name is String)) throw Exception("Invalid entity data");
    final uri = entityModel.metadata.value?.actions[0]?.url;
    if (!(uri is String) || uri.length < 1)
      throw Exception("Invalid entity data");

    Navigator.push(
        context,
        MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => RegisterValidationPage(
                entityId: entityId,
                entityName: name,
                backendUri: uri,
                validationToken: validationToken)));
  } catch (err) {
    throw Exception(getText(context, "error.couldNotFetchTheEntityDetails"));
  }
}

// showSignatureScreen(
//     {@required BuildContext context,
//     @required String payload,
//     @required String returnUri}) {
//   if (!(payload is String) || payload.length == 0) {
//     throw LinkingError("Invalid payload");
//   } else if (!(returnUri is String) || returnUri.length == 0) {
//     throw LinkingError("Invalid returnUri");
//   }

//   payload = Uri.decodeFull(payload);
//   final rtnUri = Uri.parse(returnUri);
//   if (rtnUri == null) throw LinkingError("Invalid return URI");

//   final SignModalArguments args =
//       SignModalArguments(payload: payload, returnUri: rtnUri);

//   Navigator.pushNamed(Globals.navigatorKey.currentContext, "/signature", arguments: args);
// }

// /////////////////////////////////////////////////////////////////////////////
// / HELPERS
// /////////////////////////////////////////////////////////////////////////////

List<String> extractLinkSegments(Uri link) {
  if (!(link is Uri)) throw Exception();

  // DEEP LINKS
  // - app.vocdoni.net, app.dev.vocdoni.net => Use as they are
  //    - https://<domain>/entities/#/0x462fc85288f9b204d5a146901b2b6a148bddf0ba1a2fb5c87fb33ff22891fb46
  //    - https://<domain>/validation/#/0x-entity-id/0x-token
  // - vocdoni.page.link, vocdonidev.page.link => Extract the `link` parameter

  // QR SCAN LINKS
  // - vocdoni.link, dev.vocdoni.link
  //    - https://vocdoni.link/entities/0x462fc85288f9b204d5a146901b2b6a148bddf0ba1a2fb5c87fb33ff22891fb46
  //    - https://vocdoni.link/validation/0x462fc85288f9b204d5a146901b2b6a148bddf0ba1a2fb5c87fb33ff22891fb46/token-1234

  if (link.host == "vocdoni.page.link" || link.host == "vocdonidev.page.link") {
    final extractedUrl = link.queryParameters["link"];
    link = Uri.parse(extractedUrl);
  }

  if (link.pathSegments.length < 1) {
    if (kReleaseMode)
      throw Exception();
    else
      return [];
  }

  // Merge path and hash segments
  final pathSegments =
      link.pathSegments.where((str) => str.length > 0).cast<String>().toList();
  final hashSegments = link.fragment
      .split("/")
      .where((str) => str.length > 0)
      .cast<String>()
      .toList();

  final allSegments = <String>[];
  allSegments.addAll(pathSegments);
  allSegments.addAll(hashSegments);

  return allSegments;
}

// /////////////////////////////////////////////////////////////////////////////
// / GENERATORS
// /////////////////////////////////////////////////////////////////////////////

String generateEntityLink(String entityId) {
  final domain = AppConfig.linkingDomain;
  return "https://$domain/entities/$entityId";
}
