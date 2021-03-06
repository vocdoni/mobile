import "package:flutter/material.dart";
import 'package:vocdoni/data-models/entity.dart';
import 'package:vocdoni/data-models/process.dart';
import 'package:vocdoni/lib/i18n.dart';
import 'package:vocdoni/lib/globals.dart';
import 'package:dvote/dvote.dart';
import 'package:eventual/eventual-builder.dart';
import 'package:vocdoni/widgets/card-poll.dart';
import 'package:vocdoni/widgets/card-post.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import "package:vocdoni/lib/extensions.dart";

// Used to merge and sort feed items
class CardItem {
  final EntityModel entity;
  final ProcessModel process;
  final FeedPost post;
  final DateTime date;

  CardItem(
      {@required this.entity, @required this.date, this.process, this.post});
}

class HomeContentTab extends StatefulWidget {
  HomeContentTab();

  @override
  _HomeContentTabState createState() => _HomeContentTabState();
}

class _HomeContentTabState extends State<HomeContentTab> {
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  @override
  void initState() {
    super.initState();
    Globals.analytics.trackPage("Home");
  }

  void _onRefresh() {
    final currentAccount = Globals.appState.currentAccount;

    currentAccount.refresh().then((_) {
      _refreshController.refreshCompleted();
    }).catchError((err) {
      _refreshController.refreshFailed();
    });
  }

  @override
  Widget build(ctx) {
    return EventualBuilder(
      notifier: Globals.appState.selectedAccount,
      builder: (context, _, __) {
        final currentAccount = Globals.appState.currentAccount;
        if (currentAccount == null) return buildNoEntries(ctx);
        return EventualBuilder(
          notifiers: [
            currentAccount.entities,
            Globals.processPool,
            Globals.feedPool
          ],
          builder: (context, _, __) {
            if (!currentAccount.entities.hasValue ||
                currentAccount.entities.value.length == 0)
              return buildNoEntries(ctx);

            final items = _digestCardList();
            if (items.length == 0) return buildNoEntries(ctx);

            return SmartRefresher(
              enablePullDown: true,
              enablePullUp: false,
              header: WaterDropHeader(
                complete: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(Icons.done, color: Colors.grey),
                      Container(width: 10.0),
                      Text(getText(context, "main.refreshCompleted"),
                          style: TextStyle(color: Colors.grey))
                    ]),
                failed: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(Icons.close, color: Colors.grey),
                      Container(width: 10.0),
                      Text(getText(context, "main.couldNotRefresh"),
                          style: TextStyle(color: Colors.grey))
                    ]),
              ),
              controller: _refreshController,
              onRefresh: _onRefresh,
              child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (BuildContext ctx, int index) =>
                      items[index] ?? Container()),
            );
          },
        );
      },
    );
  }

  Widget buildNoEntries(BuildContext ctx) {
    return Container(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.rss_feed,
              size: 50.0,
              color: Colors.black38,
            ),
            Text(getText(context, "main.prettyLonleyInHere") + "   ¯\\_(ツ)_/¯")
                .withTopPadding(20),
          ],
        ));
  }

  // INERNAL

  List<Widget> _digestCardList() {
    if (!Globals.accountPool.hasValue || Globals.accountPool.value.length == 0)
      return [];

    final currentAccount = Globals.appState.currentAccount;
    if (currentAccount == null ||
        !currentAccount.entities.hasValue ||
        currentAccount.entities.value.length == 0) return [];

    final availableItems = List<CardItem>();

    for (final entity in currentAccount.entities.value) {
      if (entity.feed.hasValue) {
        entity.feed.value.items.forEach((post) {
          if (!(post is FeedPost)) return;
          final date = DateTime.tryParse(post.datePublished);
          final item = CardItem(entity: entity, date: date, post: post);
          availableItems.add(item);
        });
      }

      if (entity.processes.hasValue) {
        entity.processes.value.forEach((process) {
          if (!(process is ProcessModel) || process.metadata.isLoading)
            return;
          else if (!process.metadata.hasValue) return;

          availableItems.add(CardItem(
              entity: entity, date: process.endDate.value, process: process));
        });
      }
    }

    availableItems.sort((a, b) {
      if (!(a?.date is DateTime) && !(b?.date is DateTime))
        return 0;
      else if (!(a?.date is DateTime))
        return -1;
      else if (!(b?.date is DateTime)) return 1;
      return b.date.compareTo(a.date);
    });

    int listIdx = 0;
    final result = availableItems
        .map((item) {
          if (item.process != null)
            return CardPoll(item.process, item.entity, listIdx++);
          else if (item.post != null)
            return CardPost(item.post, item.entity, listIdx++);
          return Container();
        })
        .cast<Widget>()
        .toList();

    return result;
  }
}
