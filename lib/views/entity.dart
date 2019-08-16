import 'dart:convert';

import 'package:feather_icons_flutter/feather_icons_flutter.dart';
import "package:flutter/material.dart";
import 'package:flutter/services.dart';
import 'package:vocdoni/modals/web-action.dart';
import 'package:vocdoni/util/singletons.dart';
import 'package:vocdoni/widgets/ScaffoldWithImage.dart';
import 'package:vocdoni/widgets/baseButton.dart';
import 'package:vocdoni/widgets/listItem.dart';
import 'package:vocdoni/widgets/section.dart';
import 'package:vocdoni/widgets/summary.dart';
import 'package:vocdoni/widgets/toast.dart';
import 'package:vocdoni/widgets/topNavigation.dart';
import 'package:dvote/dvote.dart';
import '../lang/index.dart';
import 'package:http/http.dart' as http;
import 'package:vocdoni/constants/colors.dart';

class EntityInfo extends StatefulWidget {
  @override
  _EntityInfoState createState() => _EntityInfoState();
}

class _EntityInfoState extends State<EntityInfo> {
  bool _processingSubscription = false;
  Entity_Action _registerAction;
  List<Entity_Action> _actionsToDisplay = [];
  bool _isRegistered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    try {
      final entity = ModalRoute.of(super.context).settings.arguments;
      if (entity == null) return;
      fetchVisibleActions(entity);
    } catch (err) {
      print(err);
    }
  }

  @override
  Widget build(context) {
    final Entity entity = ModalRoute.of(context).settings.arguments;
    if (entity == null) return buildEmptyEntity(context);

    return ScaffoldWithImage(
        headerImageUrl: entity.media.header,
        title: entity.name[entity.languages[0]] ?? "(entity)",
        collapsedTitle: entity.name[entity.languages[0]] ?? "(entity)",
        subtitle: entity.name[entity.languages[0]] ?? "(entity)",
        avatarUrl: entity.media.avatar,
        leftElement: buildRegisterButton(context, entity),
        actionsBuilder: actionsBuilder,
        builder: Builder(
          builder: (ctx) {
            return SliverList(
              delegate:
                  SliverChildListDelegate(getScaffoldChildren(ctx, entity)),
            );
          },
        ));
  }

  List<Widget> actionsBuilder(BuildContext context) {
    final Entity entity = ModalRoute.of(context).settings.arguments;
    return [
      buildShareButton(context, entity),
      SizedBox(height: 48, width: paddingPage),
      buildSubscribeButton(context, entity),
      SizedBox(height: 48, width: paddingPage)
    ];
  }

  buildTest() {
    double avatarHeight = 120;
    return Container(
      height: avatarHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Container(
            constraints:
                BoxConstraints(minWidth: avatarHeight, minHeight: avatarHeight),
            child: CircleAvatar(
                backgroundColor: Colors.indigo,
                backgroundImage: NetworkImage(
                    "https://instagram.fmad5-1.fna.fbcdn.net/vp/564db12bde06a8cb360e31007fd049a6/5DDF1906/t51.2885-19/s150x150/13167299_1084444071617255_680456677_a.jpg?_nc_ht=instagram.fmad5-1.fna.fbcdn.net")),
          ),
        ],
      ),
    );
  }

  getScaffoldChildren(BuildContext context, Entity entity) {
    List<Widget> children = [];
    //children.add(buildTest());
    children.add(buildTitle(context, entity));
    children.add(buildSubscribeItem(context, entity));
    children.add(buildFeedItem(context, entity));
    children.addAll(buildActionList(context, entity));
    children.add(Section(text: "Details"));
    children.add(Summary(
      text: entity.description[entity.languages[0]],
      maxLines: 5,
    ));

    return children;
  }

  buildTitle(BuildContext context, Entity entity) {
    return ListItem(
      mainText: entity.name[entity.languages[0]],
      secondaryText: entity.entityId,
      isTitle: true,
      rightIcon: null,
      isBold: true,
    );
  }

  buildFeedItem(BuildContext context, Entity entity) {
    return ListItem(
      icon: FeatherIcons.rss,
      mainText: "Feed",
      onTap: () {
        Navigator.pushNamed(context, "/entity/activity", arguments: entity);
      },
    );
  }

  buildSubscribeItem(BuildContext context, Entity entity) {
    Identity account = identitiesBloc.getCurrentAccount();
    bool isSubscribed = identitiesBloc.isSubscribed(account, entity);
    String subscribeText = isSubscribed ? "Subscribed" : "Subscribe";
    return ListItem(
      mainText: subscribeText,
      icon: FeatherIcons.heart,
      disabled: _processingSubscription,
      rightIcon: isSubscribed ? FeatherIcons.check : null,
      rightTextPurpose: isSubscribed ? Purpose.GOOD : null,
      // purpose: Purpose.HIGHLIGHT,
      onTap: () => isSubscribed
          ? unsubscribeFromEntity(context, entity)
          : subscribeToEntity(context, entity),
    );
  }

  buildSubscribeButton(BuildContext context, Entity entity) {
    Identity account = identitiesBloc.getCurrentAccount();
    bool isSubscribed = identitiesBloc.isSubscribed(account, entity);
    String subscribeText = isSubscribed ? "Following" : "Follow";
    return BaseButton(
      text: subscribeText,
      leftIconData: isSubscribed ? FeatherIcons.check : FeatherIcons.plus,
      isDisabled: _processingSubscription,
      isSmall: true,
      style: BaseButtonStyle.OUTLINE_WHITE,
      onTap: () => isSubscribed
          ? unsubscribeFromEntity(context, entity)
          : subscribeToEntity(context, entity),
    );
  }

  buildShareButton(BuildContext context, Entity entity) {
    return BaseButton(
        leftIconData: FeatherIcons.share2,
        isSmall: false,
        style: BaseButtonStyle.NO_BACKGROUND_WHITE,
        onTap: () {
          Clipboard.setData(ClipboardData(text: entity.entityId));
          showMessage("Identity ID copied on the clipboard",
              context: context, purpose: Purpose.GUIDE);
        });
  }

  Future<bool> isActionVisible(Entity_Action action, String entityId) async {
    if (action.visible == null || action.visible == "always") return true;

    String publicKey = identitiesBloc.getCurrentAccount().identityId;
    int timestamp = new DateTime.now().millisecondsSinceEpoch;

    // TODO: Get the private key to sign appropriately
    final privateKey = "";
    debugPrint(
        "TODO: Retrieve the private key to sign the action visibility request");

    try {
      Map payload = {
        "type": action.type,
        'publicKey': publicKey,
        "entityId": entityId,
        "timestamp": timestamp,
        "signature": ""
      };

      if (privateKey != "") {
        payload["signature"] = await signString(
            jsonEncode({"timestamp": timestamp.toString()}), privateKey);
      } else {
        payload["signature"] = "0x"; // TODO: TEMP
      }

      Map<String, String> headers = {
        'Content-type': 'application/json',
        'Accept': 'application/json',
      };

      var response = await http.post(action.visible,
          body: jsonEncode(payload), headers: headers);
      if (response.statusCode != 200 || !(response.body is String))
        return false;
      final body = jsonDecode(response.body);
      if (body is Map && body["visible"] == true) return true;
    } catch (err) {
      return false;
    }

    return false;
  }

  Widget buildEmptyEntity(BuildContext ctx) {
    return Scaffold(
        appBar: TopNavigation(
          title: "",
        ),
        body: Center(
          child: Text("(No entity)"),
        ));
  }

  Future<void> fetchVisibleActions(Entity entity) async {
    final List<Entity_Action> actionsToDisplay = [];
    Entity_Action registerAction;

    for (Entity_Action action in entity.actions) {
      if (action.register == true) {
        if (registerAction != null)
          continue; //only one registerAction is supported
        registerAction = action;
        bool isRegistered = await isActionVisible(action, entity.entityId);
        setState(() {
          _registerAction = registerAction;
          _isRegistered = isRegistered;
        });
      } else {
        if (await isActionVisible(action, entity.entityId)) {
          actionsToDisplay.add(action);
        }
      }
    }
    setState(() {
      _actionsToDisplay = actionsToDisplay;
    });
  }

  Entity_Action getRegisterAction(Entity entity) {
    for (Entity_Action action in entity.actions) {
      if (action.register == true) return action;
    }
    return null;
  }

  Widget buildRegisterButton(BuildContext ctx, Entity entity) {
    if (_registerAction == null) return Container();

    if (true)
      return BaseButton(
        purpose: Purpose.GUIDE,
        leftIconData: FeatherIcons.check,
        text: "Registered",
        isSmall: true,
        style: BaseButtonStyle.FILLED,
        isDisabled: true,
      );
    else
      return BaseButton(
        purpose: Purpose.HIGHLIGHT,
        leftIconData: FeatherIcons.feather,
        text: "Register",
        isSmall: true,
        onTap: () {
          if (_registerAction.type == "browser") {
            onBrowserAction(ctx, _registerAction, entity);
          }
        },
      );
  }

  List<Widget> buildActionList(BuildContext ctx, Entity entity) {
    final List<Widget> actionsToShow = [];

    actionsToShow.add(Section(text: "Actions"));

    if (_actionsToDisplay.length == 0 || _registerAction == null) {
      return [
        ListItem(
          mainText: "No Actions definied",
          disabled: true,
          rightIcon: null,
          icon: FeatherIcons.helpCircle,
        )
      ];
    }

    bool actionsDisabled = false;
    if (!_isRegistered) {
      actionsDisabled = true;
      final entityName = entity.name[entity.languages[0]];
      ListItem noticeItem = ListItem(
        mainText: "Regsiter to $entityName first",
        secondaryText: null,
        rightIcon: null,
        disabled: false,
        purpose: Purpose.HIGHLIGHT,
      );
      actionsToShow.add(noticeItem);
    }

    for (Entity_Action action in _actionsToDisplay) {
      ListItem item;
      if (action.type == "browser") {
        if (!(action.name is Map) ||
            !(action.name[entity.languages[0]] is String)) return null;

        item = ListItem(
          icon: FeatherIcons.arrowRightCircle,
          mainText: action.name[entity.languages[0]],
          secondaryText: action.visible,
          disabled: actionsDisabled,
          onTap: () {
            onBrowserAction(ctx, action, entity);
          },
        );
      } else {
        item = ListItem(
          mainText: action.name[entity.languages[0]],
          secondaryText: "Action type not supported yet: " + action.type,
          icon: FeatherIcons.helpCircle,
          disabled: true,
        );
      }

      actionsToShow.add(item);
    }

    return actionsToShow;
  }

  onBrowserAction(BuildContext ctx, Entity_Action action, Entity entity) {
    final String url = action.url;
    final String title =
        action.name[entity.languages[0]] ?? entity.name[entity.languages[0]];

    final route = MaterialPageRoute(
        builder: (context) => WebAction(
              url: url,
              title: title,
            ));
    Navigator.push(ctx, route);
  }

  unsubscribeFromEntity(BuildContext ctx, Entity entity) async {
    setState(() {
      _processingSubscription = true;
    });
    Identity account = identitiesBloc.getCurrentAccount();
    await identitiesBloc.unsubscribeEntityFromAccount(entity, account);
    showMessage(
        Lang.of(ctx)
            .get("You will no longer see this organization in your feed"),
        context: ctx,
        purpose: Purpose.NONE);
    setState(() {
      _processingSubscription = false;
    });
  }

  subscribeToEntity(BuildContext ctx, Entity entity) async {
    setState(() {
      _processingSubscription = true;
    });

    try {
      Identity account = identitiesBloc.getCurrentAccount();
      await identitiesBloc.subscribeEntityToAccount(entity, account);

      showMessage(Lang.of(ctx).get("Organization successfully added"),
          context: ctx, purpose: Purpose.GOOD);
    } catch (err) {
      if (err == "Already subscribed") {
        showMessage(
            Lang.of(ctx).get(
              "You are already subscribed to this entity",
            ),
            context: ctx,
            purpose: Purpose.DANGER);
      } else {
        showMessage(
            Lang.of(ctx).get("The subscription could not be registered"),
            context: ctx,
            purpose: Purpose.DANGER);
      }
    }
    setState(() {
      _processingSubscription = false;
    });
  }

  goBack(BuildContext ctx) {
    Navigator.pop(ctx, false);
  }
}
