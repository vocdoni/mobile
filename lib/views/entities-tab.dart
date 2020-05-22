import 'package:feather_icons_flutter/feather_icons_flutter.dart';
import "package:flutter/material.dart";
import 'package:vocdoni/data-models/entity.dart';
import 'package:vocdoni/data-models/process.dart';
import 'package:vocdoni/lib/i18n.dart';
import 'package:vocdoni/lib/singletons.dart';
import 'package:eventual/eventual-builder.dart';
import 'package:vocdoni/views/entity-info-page.dart';
import 'package:dvote_common/widgets/baseCard.dart';
import 'package:dvote_common/widgets/card-loading.dart';
import 'package:dvote_common/widgets/listItem.dart';

class EntitiesTab extends StatefulWidget {
  EntitiesTab();

  @override
  _EntitiesTabState createState() => _EntitiesTabState();
}

class _EntitiesTabState extends State<EntitiesTab> {
  @override
  void initState() {
    super.initState();
    globalAnalytics.trackPage("EntitiesTab");
  }

  @override
  Widget build(ctx) {
    final currentAccount = globalAppState.currentAccount;

    if (currentAccount == null) return buildNoEntities(ctx);

    // Rebuild if the pool changes (not the items)
    return EventualBuilder(
        notifiers: [currentAccount.entities, currentAccount.identity],
        builder: (context, _, __) {
          if (!currentAccount.entities.hasValue ||
              currentAccount.entities.value.length == 0) {
            return buildNoEntities(ctx);
          }

          return ListView.builder(
              itemCount: currentAccount.entities.value.length,
              itemBuilder: (BuildContext context, int index) {
                final entity = currentAccount.entities.value[index];

                if (entity.metadata.hasValue)
                  return buildCard(ctx, entity);
                else if (entity.metadata.isLoading)
                  return CardLoading(getText(context, "Loading entity..."));
                return buildEmptyMetadataCard(ctx, entity);
              });
        });
  }

  Widget buildEmptyMetadataCard(BuildContext ctx, EntityModel entityModel) {
    return BaseCard(children: [
      ListItem(
          mainText: entityModel.reference.entityId,
          avatarHexSource: entityModel.reference.entityId,
          isBold: true,
          onTap: () => onTapEntity(ctx, entityModel))
    ]);
  }

  Widget buildCard(BuildContext ctx, EntityModel ent) {
    return BaseCard(children: [
      buildName(ctx, ent),
      buildFeedRow(ctx, ent),
      buildParticipationRow(ctx, ent),
    ]);
  }

  int getFeedPostCount(EntityModel entity) {
    if (!entity.feed.hasValue)
      return 0;
    else if (entity.feed.value.items is List)
      return entity.feed.value.items.length;
    return 0;
  }

  Widget buildName(BuildContext ctx, EntityModel entity) {
    String title =
        entity.metadata.value.name[entity.metadata.value.languages[0]];
    return ListItem(
        heroTag: entity.reference.entityId + title,
        mainText: title,
        avatarUrl: entity.metadata.value.media.avatar,
        avatarText: title,
        avatarHexSource: entity.reference.entityId,
        isBold: true,
        onTap: () => onTapEntity(ctx, entity));
  }

  Widget buildParticipationRow(BuildContext ctx, EntityModel entity) {
    // Consume intermediate values, not present from the root context and rebuild if
    // the entity's process list changes
    return EventualBuilder(
      notifier: entity.processes,
      builder: (context, _, __) {
        int itemCount = 0;
        if (entity.processes.hasValue) {
          final availableProcesses = List<ProcessModel>();
          if (entity.processes.hasValue) {
            availableProcesses.addAll(
                entity.processes.value.where((item) => item.metadata.hasValue));
          }
          itemCount = availableProcesses.length;
        }

        return ListItem(
            mainText: getText(context, "Participation"),
            icon: FeatherIcons.mail,
            rightText: itemCount.toString(),
            rightTextIsBadge: true,
            onTap: () => onTapParticipation(ctx, entity),
            disabled: itemCount == 0);
      },
    );
  }

  Widget buildFeedRow(BuildContext ctx, EntityModel entity) {
    // Consume intermediate values, not present from the root context and rebuild if
    // the entity's news feed changes
    return EventualBuilder(
      notifier: entity.feed,
      builder: (context, _, __) {
        final feedPostAmount = getFeedPostCount(entity);
        return ListItem(
            mainText: getText(context, "Feed"),
            icon: FeatherIcons.rss,
            rightText: feedPostAmount.toString(),
            rightTextIsBadge: true,
            onTap: () => onTapFeed(ctx, entity),
            disabled: feedPostAmount == 0);
      },
    );
  }

  Widget buildNoEntities(BuildContext ctx) {
    // TODO: UI
    return Center(
      child: Text(getText(context, "No entities")),
    );
  }

  onTapEntity(BuildContext ctx, EntityModel entity) {
    final route =
        MaterialPageRoute(builder: (context) => EntityInfoPage(entity));
    Navigator.push(ctx, route);
  }

  onTapParticipation(BuildContext ctx, EntityModel entity) {
    Navigator.pushNamed(ctx, "/entity/participation", arguments: entity);
  }

  onTapFeed(BuildContext ctx, EntityModel entity) {
    Navigator.pushNamed(ctx, "/entity/feed", arguments: entity);
  }
}
