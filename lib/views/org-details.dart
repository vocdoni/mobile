import 'package:dvote_common/lib/common.dart';
import 'package:dvote_common/widgets/htmlSummary.dart';
import 'package:eventual/eventual-notifier.dart';
import 'package:feather_icons_flutter/feather_icons_flutter.dart';
import 'package:vocdoni/constants/settings.dart';
import 'package:vocdoni/data-models/process.dart';
import 'package:vocdoni/lib/app-links.dart';
import 'package:vocdoni/lib/logger.dart';
import "package:flutter/material.dart";
import 'package:vocdoni/data-models/entity.dart';
import 'package:vocdoni/lib/globals.dart';
import 'package:eventual/eventual-builder.dart';
import 'package:vocdoni/view-modals/action-register.dart';
import 'package:vocdoni/view-modals/qr-show-modal.dart';
// import 'package:vocdoni/view-modals/web-action.dart';
import 'package:dvote_common/widgets/ScaffoldWithImage.dart';
import 'package:dvote_common/widgets/alerts.dart';
import 'package:dvote_common/widgets/baseButton.dart';
import 'package:dvote_common/widgets/listItem.dart';
import 'package:dvote_common/widgets/section.dart';
import 'package:dvote_common/widgets/toast.dart';
// import 'package:dvote/dvote.dart';
import 'package:vocdoni/lib/i18n.dart';
import 'package:dvote_common/constants/colors.dart';

class OrgDetails extends StatefulWidget {
  final EntityModel entityModel;

  OrgDetails(this.entityModel) {
    Globals.analytics
        .trackPage("OrgDetails", entityId: entityModel.reference.entityId);
  }

  @override
  _OrgDetailsState createState() => _OrgDetailsState();
}

class _OrgDetailsState extends State<OrgDetails> {
  bool _processingSubscription = false;
  final notificationsEnabledNotifier = EventualNotifier<bool>(false);

  @override
  void initState() {
    super.initState();

    // detached async
    widget.entityModel.refresh().catchError((err) {
      logger.log(err);
    });
  }

  @override
  Widget build(context) {
    // Rebuild when the metadata updates
    return EventualBuilder(
      notifier: widget.entityModel.metadata,
      builder: (context, _, __) {
        return widget.entityModel.metadata.hasValue
            ? buildScaffold(context)
            : buildScaffoldWithoutMetadata(context);
      },
    );
  }

  Widget buildScaffoldWithoutMetadata(BuildContext context) {
    return ScaffoldWithImage(
        headerImageUrl: null,
        headerTag: null,
        forceHeader: true,
        appBarTitle: getText(context, "main.loading"),
        avatarText: "",
        avatarHexSource: widget.entityModel.reference.entityId,
        builder: Builder(
          builder: (ctx) {
            return SliverList(
                delegate: SliverChildListDelegate(
              [
                buildSubscribeItem(ctx),
                buildTitleWithoutMetadata(ctx),
                buildLoadingStatus(),
              ],
            ));
          },
        ));
  }

  Widget buildLoadingStatus() {
    return EventualBuilder(
      notifiers: [
        widget.entityModel.metadata,
        widget.entityModel.processes,
        widget.entityModel.feed
      ],
      builder: (context, _, __) {
        if (widget.entityModel.metadata.isLoading)
          return ListItem(
            mainText: getText(context, "main.fetchingDetails"),
            rightIcon: null,
            isSpinning: true,
          );
        else if (widget.entityModel.processes.isLoading)
          return ListItem(
            mainText: getText(context, "main.fetchingParticipation"),
            rightIcon: null,
            isSpinning: true,
          );
        else if (widget.entityModel.feed.isLoading)
          return ListItem(
            mainText: getText(context, "main.fetchingNews"),
            rightIcon: null,
            isSpinning: true,
          );
        else if (widget.entityModel.metadata.hasError)
          return ListItem(
            mainText: getText(context, "error.theMetadataIsNotAvailable"),
            purpose: Purpose.DANGER,
            rightTextPurpose: Purpose.DANGER,
            onTap: () => widget.entityModel
                .refreshMetadata(force: true, skipChildren: true),
            rightIcon: FeatherIcons.refreshCw,
          );
        else if (widget.entityModel.feed.hasError)
          return ListItem(
            mainText: getText(context, "error.theMetadataIsNotAvailable"),
            purpose: Purpose.DANGER,
            rightTextPurpose: Purpose.DANGER,
            onTap: () => widget.entityModel.refreshFeed(),
            rightIcon: FeatherIcons.refreshCw,
          );
        else
          return Container();
      },
    );
  }

  Widget buildScaffold(BuildContext context) {
    String headerUrl = widget.entityModel.metadata.value.media.header;
    if (headerUrl.startsWith("ipfs"))
      headerUrl = processIpfsImageUrl(headerUrl, ipfsDomain: IPFS_DOMAIN);
    String avatarUrl = widget.entityModel.metadata.value.media.avatar;
    if (avatarUrl.startsWith("ipfs"))
      avatarUrl = processIpfsImageUrl(avatarUrl, ipfsDomain: IPFS_DOMAIN);
    return ScaffoldWithImage(
        headerImageUrl: headerUrl,
        headerTag: widget.entityModel.reference.entityId +
            widget.entityModel.metadata.value.media.header,
        forceHeader: true,
        appBarTitle: widget
            .entityModel.metadata.value.name[Globals.appState.currentLanguage],
        avatarUrl: avatarUrl,
        avatarText: widget
            .entityModel.metadata.value.name[Globals.appState.currentLanguage],
        avatarHexSource: widget.entityModel.reference.entityId,
        leftElement: buildRegisterButton(context),
        actionsBuilder: actionsBuilder,
        builder: Builder(
          builder: (ctx) {
            final children = getScaffoldChildren(ctx);
            return SliverList(
              delegate: SliverChildListDelegate(children),
            );
          },
        ));
  }

  List<Widget> actionsBuilder(BuildContext context) {
    return [
      buildShareButton(context),
      // SizedBox(height: 48, width: paddingPage),
      //buildSubscribeButton(context),
      //SizedBox(height: 48, width: paddingPage)
    ];
  }

  getScaffoldChildren(BuildContext context) {
    List<Widget> children = [];
    children.add(buildTitle(context));
    children.add(buildLoadingStatus());
    children.add(buildFeedRow(context));
    children.add(buildParticipationRow(context));
    children.add(buildNotificationsRow(context));
    // TODO: show back?
    // children.add(buildActionList(context));
    children.add(Section(text: getText(context, "main.details")));
    children.add(HtmlSummary(
      htmlString: widget.entityModel.metadata.value
              .description[Globals.appState.currentLanguage] +
          "<br><br>" +
          getText(context, "main.uniqueIdentifierColon") +
          " " +
          widget.entityModel.reference.entityId,
      isSecondary: false,
    ));
    children.add(Section(text: getText(context, "main.manage")));
    children.add(buildShareItem(context));
    children.add(buildSubscribeItem(context));

    return children;
  }

  buildTitle(BuildContext context) {
    String title = widget
        .entityModel.metadata.value.name[Globals.appState.currentLanguage];
    return ListItem(
      heroTag: widget.entityModel.reference.entityId + title,
      mainText: title,
      mainTextMultiline: 2,
      // secondaryText: widget.entityModel.reference.entityId,
      isTitle: true,
      rightIcon: null,
      isBold: true,
    );
  }

  buildTitleWithoutMetadata(BuildContext context) {
    return ListItem(
      mainText: "...",
      // secondaryText: widget.entityModel.reference.entityId,
      isTitle: true,
      rightIcon: null,
      isBold: true,
    );
  }

  buildFeedRow(BuildContext context) {
    // Rebuild when the feed updates
    return EventualBuilder(
        notifier: widget.entityModel.feed,
        builder: (context, _, __) {
          int postCount = 0;
          if (widget.entityModel.feed.hasValue) {
            postCount = widget.entityModel.feed.value.items?.length ?? 0;
          }

          return ListItem(
            icon: FeatherIcons.rss,
            mainText: getText(context, "main.feed"),
            rightText: postCount.toString(),
            rightTextIsBadge: true,
            rightTextPurpose:
                widget.entityModel.feed.hasError ? Purpose.DANGER : null,
            disabled: widget.entityModel.feed.hasError ||
                widget.entityModel.feed.isLoading ||
                postCount == 0,
            isSpinning: widget.entityModel.feed.isLoading,
            onTap: () => onShowFeed(context),
          );
        });
  }

  buildParticipationRow(BuildContext context) {
    // Rebuild when the process list updates (not the items)
    return EventualBuilder(
      notifier: widget.entityModel.processes,
      builder: (context, _, __) {
        int processCount = 0;
        if (widget.entityModel.processes.hasValue) {
          final availableProcesses = List<ProcessModel>();
          if (widget.entityModel.processes.hasValue) {
            availableProcesses.addAll(widget.entityModel.processes.value
                .where((item) => item.metadata.hasValue));
          }

          processCount = availableProcesses.length;
        }

        return ListItem(
            icon: FeatherIcons.mail,
            mainText: getText(context, "main.participation"),
            rightText: processCount.toString(),
            rightTextIsBadge: true,
            rightTextPurpose:
                widget.entityModel.processes.hasError ? Purpose.DANGER : null,
            disabled: widget.entityModel.processes.hasError ||
                widget.entityModel.processes.isLoading ||
                processCount == 0,
            isSpinning: widget.entityModel.processes.isLoading ||
                (widget.entityModel.processes.hasValue &&
                    widget.entityModel.processes.value
                        .any((proc) => proc.metadata.isLoading)),
            onTap: () {
              onShowParticipation(context);
            });
      },
    );
  }

  buildNotificationsRow(BuildContext context) {
    // Rebuild when the process list updates (not the items)
    return EventualBuilder(
      notifiers: [
        widget.entityModel.metadata,
        widget.entityModel.notificationTopics
      ],
      builder: (context, _, __) {
        widget.entityModel.metadata.value.meta;
        final wantsNotifications = widget.entityModel.hasNotificationsEnabled();

        return ListItem(
            icon: wantsNotifications ? FeatherIcons.bell : FeatherIcons.bellOff,
            mainText: wantsNotifications
                ? getText(context, "main.notificationsEnabled")
                : getText(context, "main.notificationsDisabled"),
            rightText: "",
            // rightTextIsBadge: true,
            // rightTextPurpose:
            //     widget.entityModel.processes.hasError ? Purpose.DANGER : null,
            isSpinning: widget.entityModel.notificationTopics.isLoading,
            onTap: () => toggleNotificationsSubscription(context));
      },
    );
  }

  buildSubscribeItem(BuildContext context) {
    final currentAccount = Globals.appState.currentAccount;
    if (currentAccount == null) throw Exception("Internal error");

    bool isSubscribed =
        currentAccount.isSubscribed(widget.entityModel.reference);
    String subscribeText = isSubscribed
        ? getText(context, "main.following")
        : getText(context, "main.follow");

    // Rebuild when the selected account's identity updates
    return EventualBuilder(
        notifiers: [
          currentAccount.identity
        ], // when peers > entities are updated, identity emits an event
        builder: (context, _, __) => ListItem(
              mainText: subscribeText,
              icon: FeatherIcons.heart,
              disabled: _processingSubscription,
              isSpinning: _processingSubscription,
              rightIcon: isSubscribed ? FeatherIcons.check : null,
              rightTextPurpose: isSubscribed ? Purpose.GOOD : null,
              onTap: () => isSubscribed
                  ? unsubscribeFromEntity(context)
                  : subscribeToEntity(context),
            ));
  }

  // buildSubscribeButton(BuildContext context) {
  //   final currentAccount = Globals.appState.currentAccount;
  //   if (currentAccount == null) throw Exception("Internal error");

  //   // No need to use EventualBuilder here, since the only place that can change the subscription status is here.
  //   // Hence, we don't need to worry about rebuilding on external updates

  //   bool isSubscribed =
  //       currentAccount.isSubscribed(widget.entityModel.reference);
  //   String subscribeText = isSubscribed ? "main.following" : "main.follow";

  //   return BaseButton(
  //       text: subscribeText,
  //       leftIconData: isSubscribed ? FeatherIcons.check : FeatherIcons.plus,
  //       isDisabled: _processingSubscription,
  //       isSmall: true,
  //       style: BaseButtonStyle.OUTLINE_WHITE,
  //       onTap: () {
  //         if (isSubscribed)
  //           unsubscribeFromEntity(context);
  //         else
  //           subscribeToEntity(context);
  //       });
  // }

  buildShareItem(BuildContext context) {
    return ListItem(
        mainText: getText(context, "main.shareOrganization"),
        icon: FeatherIcons.share2,
        rightIcon: null,
        onTap: () => onShare(context));
  }

  buildShareButton(BuildContext context) {
    return BaseButton(
        leftIconData: FeatherIcons.share2,
        isSmall: false,
        style: BaseButtonStyle.NO_BACKGROUND_WHITE,
        onTap: () => onShare(context));
  }

  buildRegisterButton(BuildContext ctx) {
    // TODO: Temporarily disabled
    // TODO: Reenable
    return null;

    // Rebuild if `isRegistered` changes
    return EventualBuilder(
      notifier: widget.entityModel.isRegistered,
      builder: (context, _, __) {
        if (widget.entityModel.isRegistered.hasError ||
            widget.entityModel.registerAction.hasError)
          return Container();
        else if (!widget.entityModel.isRegistered.hasValue ||
            !widget.entityModel.registerAction.hasValue)
          return Container();
        else if (!widget.entityModel.isRegistered.value) {
          // Not yet
          return BaseButton(
            purpose: Purpose.HIGHLIGHT,
            leftIconData: FeatherIcons.feather,
            text: getText(context, "main.register"),
            // isSmall: true,
            onTap: () => onTapRegister(context),
          );
        }

        // Already registered
        return BaseButton(
          purpose: Purpose.HIGHLIGHT,
          leftIconData: FeatherIcons.check,
          text: getText(context, "main.registered"),
          // isSmall: true,
          style: BaseButtonStyle.FILLED,
          isDisabled: true,
        );
      },
    );
  }

  // Widget buildActionList(BuildContext ctx) {
  //   // Rebuild if `visibleActions` changes
  //   return EventualBuilder(
  //     notifier: widget.entityModel.visibleActions,
  //     builder: (context, _, __) {
  //       final List<Widget> actionsToShow = [];

  //       actionsToShow.add(Section(text: getText(context, "main.actions")));

  //       if (widget.entityModel.visibleActions.hasError) {
  //         return ListItem(
  //           mainText: getText(context, widget.entityModel.visibleActions.errorMessage),
  //           purpose: Purpose.DANGER,
  //           rightIcon: null,
  //           rightTextPurpose: Purpose.DANGER,
  //         );
  //       } else if (!widget.entityModel.visibleActions.hasValue ||
  //           widget.entityModel.visibleActions.value.length == 0) {
  //         return ListItem(
  //           mainText: getText(context, "main.noActionsDefined"),
  //           disabled: true,
  //           rightIcon: null,
  //           icon: FeatherIcons.helpCircle,
  //         );
  //       }

  //       // Unregistered warning
  //       if (!widget.entityModel.isRegistered.value) {
  //         final entityName = widget
  //             .entityModel.metadata.value.name[Globals.appState.currentLanguage];
  //         ListItem noticeItem = ListItem(
  //           mainText: getText(context, "main.registerToNameFirst")
  //               .replaceFirst("{{NAME}}", entityName),
  //           // secondaryText: null,
  //           // rightIcon: null,
  //           disabled: false,
  //           purpose: Purpose.HIGHLIGHT,
  //         );
  //         actionsToShow.add(noticeItem);
  //       }

  //       // disabled if not registered
  //       for (EntityMetadata_Action action
  //           in widget.entityModel.visibleActions.value) {
  //         ListItem item;
  //         if (action.type == "browser") {
  //           if (action.name == null ||
  //               !(action.name[Globals.appState.currentLanguage] is String))
  //             return Container();

  //           item = ListItem(
  //             icon: FeatherIcons.arrowRightCircle,
  //             mainText: action.name[Globals.appState.currentLanguage],
  //             secondaryText: action.visible,
  //             disabled: !widget.entityModel.isRegistered.value,
  //             onTap: () => onBrowserAction(ctx, action),
  //           );
  //         } else {
  //           item = ListItem(
  //             mainText: action.name[Globals.appState.currentLanguage],
  //             secondaryText: getText(context, "main.actionNotSupported"),
  //             icon: FeatherIcons.helpCircle,
  //             disabled: true,
  //           );
  //         }

  //         actionsToShow.add(item);
  //       }

  //       return ListView(children: actionsToShow);
  //     },
  //   );
  // }

  // EVENTS

  onShare(BuildContext context) {
    // Entry points: widget.entityModel.reference.entryPoints (unused)
    final link = generateEntityLink(widget.entityModel.reference.entityId);

    Navigator.push(
        context,
        MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => QrShowModal(
                widget.entityModel.metadata.hasValue
                    ? widget.entityModel.metadata.value
                        .name[Globals.appState.currentLanguage]
                    : getText(context, "main.entity"),
                link)));
  }

  onShowFeed(BuildContext context) {
    Navigator.pushNamed(context, "/entity/feed", arguments: widget.entityModel);
  }

  onShowParticipation(BuildContext context) {
    Navigator.pushNamed(context, "/entity/participation",
        arguments: widget.entityModel);
  }

  toggleNotificationsSubscription(BuildContext context) async {
    final isSubscribed = widget.entityModel.hasNotificationsEnabled();

    try {
      if (isSubscribed)
        await widget.entityModel.disableNotifications();
      else
        await widget.entityModel.enableNotifications();

      final msg = isSubscribed
          ? getText(context, "main.notificationsHaveBeenDisabledForTheEntity")
          : getText(context, "main.notificationsHaveBeenEnabledForTheEntity");
      showMessage(msg, context: context, purpose: Purpose.GOOD);
    } catch (err) {
      final msg =
          getText(context, "error.theNotificationSettingsCouldNotBeUpdated");
      showMessage(msg, context: context, purpose: Purpose.WARNING);
    }
  }

  onTapRegister(BuildContext context) {
    // TODO send push token
    final action = widget.entityModel.metadata.value.actions.first;
    final route = MaterialPageRoute(
        builder: (context) =>
            ActionRegisterPage(action, widget.entityModel.reference.entityId));
    Navigator.push(context, route)
        .then((_) => widget.entityModel.refreshVisibleActions(force: true));
  }

  // onBrowserAction(BuildContext ctx, EntityMetadata_Action action) {
  //   final url = action.url;
  //   final title = action.name[Globals.appState.currentLanguage] ??
  //       widget.entityModel.metadata.value.name[Globals.appState.currentLanguage];

  //   final route = MaterialPageRoute(
  //       builder: (context) => WebAction(
  //             url: url,
  //             title: title,
  //           ));
  //   Navigator.push(ctx, route)
  //       .then((_) => widget.entityModel.refreshVisibleActions(true));
  // }

  subscribeToEntity(BuildContext ctx) async {
    setState(() => _processingSubscription = true);

    try {
      final currentAccount = Globals.appState.currentAccount;
      if (currentAccount == null)
        throw Exception("Internal error: null account");

      await currentAccount.subscribe(widget.entityModel);
      setState(() => _processingSubscription = false);

      showMessage(getText(ctx, "main.organizationSuccessfullyAdded"),
          context: ctx, purpose: Purpose.GOOD);
    } on Exception catch (err) {
      if (!mounted) return;
      setState(() => _processingSubscription = false);

      if (err.toString() == "Exception: Already subscribed") {
        final msg = getText(ctx, "main.youAreAlreadySubscribedToThisEntity");
        showMessage(msg, context: ctx, purpose: Purpose.DANGER);
      } else {
        showMessage(getText(ctx, "error.theSubscriptionCouldNotBeRegistered"),
            context: ctx, purpose: Purpose.DANGER);
      }
    }
  }

  unsubscribeFromEntity(BuildContext ctx) async {
    final msg = getText(ctx, "main.youAreAboutToStopFollowingTheEntity") +
        "\n" +
        getText(ctx, "main.doYouWantToContinue");

    final confirmUnsubscribe = await showPrompt(msg,
        title: getText(ctx, "main.unsubscribe"),
        okButton: getText(ctx, "main.ok"),
        cancelButton: getText(ctx, "main.cancel"),
        context: ctx);
    if (confirmUnsubscribe != true) return;

    setState(() => _processingSubscription = true);
    try {
      final currentAccount = Globals.appState.currentAccount;
      if (currentAccount == null)
        throw Exception("Internal error: null account");

      await currentAccount.unsubscribe(widget.entityModel.reference);

      if (!mounted) return;
      setState(() => _processingSubscription = false);

      showMessage(
          getText(ctx, "main.youWillNoLongerSeeThisOrganizationInYourFeed"),
          context: ctx,
          purpose: Purpose.NONE);
    } catch (err) {
      if (!mounted) return;
      setState(() => _processingSubscription = false);
      showMessage(getText(ctx, "error.theSubscriptionCouldNotBeCanceled"),
          context: ctx, purpose: Purpose.DANGER);
    }
  }

  goBack(BuildContext ctx) {
    Navigator.pop(ctx, false);
  }
}
