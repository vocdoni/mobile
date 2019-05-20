import "package:flutter/material.dart";
import 'package:vocdoni/modals/web-action.dart';
import 'package:vocdoni/util/singletons.dart';
// import 'package:vocdoni/views/organization-activity.dart';
import 'package:vocdoni/widgets/listItem.dart';
import 'package:vocdoni/widgets/pageTitle.dart';
import 'package:vocdoni/widgets/section.dart';
import 'package:vocdoni/widgets/alerts.dart';
import '../lang/index.dart';

class OrganizationInfo extends StatelessWidget {
  @override
  Widget build(context) {
    final Organization organization = ModalRoute.of(context).settings.arguments;
    if (organization == null) return buildEmptyOrganization(context);

    bool alreadySubscribed = false;
    if (appStateBloc.current != null &&
        appStateBloc.current.selectedIdentity >= 0) {
      final Identity currentIdentity =
          identitiesBloc.current[appStateBloc.current.selectedIdentity];
      if (currentIdentity != null &&
          appStateBloc.current.selectedOrganization >= 0 &&
          currentIdentity.organizations.length > 0) {
        alreadySubscribed = currentIdentity.organizations
            .any((o) => o.entityId == organization.entityId);
      }
    }

    return Scaffold(
      body: ListView(
        children: <Widget>[
          PageTitle(
            title: organization.name,
            subtitle: organization.entityId,
          ),
          Section(text: "Description"),
          Text(
            organization.description[
                organization.languages[0]], // TODO: DETECT LANGUAGE
            textAlign: TextAlign.center,
          ),
          Section(text: "Actions"),
          ListItem(
            text: "Activity",
            onTap: () {
              Navigator.pushNamed(context, "/organizations/activity",
                  arguments: organization);
            },
          ),
          alreadySubscribed
              ? buildAlreadySubscribed(context, organization) // CUSTOM ACTIONS
              : buildSubscriptionTiles(context, organization) // SUBSCRIBE
        ],
      ),
    );
  }

  /// NO ORGANIZATION

  Widget buildEmptyOrganization(BuildContext ctx) {
    // TODO: UI
    return Scaffold(
        body: Center(
      child: Text("(No organization)"),
    ));
  }

  /// ALREADY REGISTERED CONTENT

  Widget buildAlreadySubscribed(BuildContext ctx, Organization organization) {
    // TODO: Handle all actions
    final List<Widget> actions = organization.actions
        .map((action) {
          if (!(action is Map) ||
              !(action["name"] is Map) ||
              !(action["name"][organization.languages[0]] is String))
            return null;
          return ListItem(
            text: action["name"][organization.languages[0]],
            onTap: () {
              Navigator.push(
                  ctx,
                  MaterialPageRoute(
                      builder: (context) => WebAction(
                            url: action["url"],
                          )));
            },
          );
        })
        .toList()
        .where((w) => w != null)
        .toList();

    return Column(children: <Widget>[
      ...actions,
      SizedBox(height: 40),
      Text(
        Lang.of(ctx).get("You are already subscribed"),
        textAlign: TextAlign.center,
      )
    ]);
  }

  /// PROMPT TO SUBSCRIBE

  Widget buildSubscriptionTiles(BuildContext ctx, Organization organization) {
    return Column(children: <Widget>[
      ListItem(
        text: "Subscribe",
        onTap: () => confirmSubscribe(ctx),
      ),
      SizedBox(height: 40),
      Text(
        Lang.of(ctx).get("You are about to subscribe to:"),
        textAlign: TextAlign.center,
      ),
      Text(
        organization.name,
        textAlign: TextAlign.center,
      ),
      SizedBox(height: 20),
      Text(
        Lang.of(ctx).get("Using the identity:"),
        textAlign: TextAlign.center,
      ),
      Text(
        identitiesBloc.current[appStateBloc.current.selectedIdentity].alias,
        textAlign: TextAlign.center,
      )
    ]);
  }

  confirmSubscribe(BuildContext ctx) async {
    final accepts = await showPrompt(
        context: ctx,
        title: Lang.of(ctx).get("Organization"),
        text: Lang.of(ctx).get("Do you want to subscribe to the organization?"),
        okButton: Lang.of(ctx).get("Subscribe"));

    if (accepts == true) {
      Navigator.pop(ctx, true);
    }
  }

  goBack(BuildContext ctx) {
    Navigator.pop(ctx, false);
  }
}