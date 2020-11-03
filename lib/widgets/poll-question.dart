import 'package:dvote_common/widgets/spinner.dart';
import "package:flutter/material.dart";
import 'package:vocdoni/data-models/process.dart';
import 'package:vocdoni/lib/i18n.dart';
import 'dart:async';
import 'package:dvote/dvote.dart';
import 'package:vocdoni/lib/globals.dart';
import 'package:eventual/eventual-builder.dart';
import 'package:vocdoni/lib/extensions.dart';
import "dart:developer";
import 'package:rainbow_color/rainbow_color.dart';
import 'package:dvote_common/widgets/listItem.dart';
import 'package:dvote_common/widgets/section.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:dvote_common/constants/colors.dart';
import 'package:feather_icons_flutter/feather_icons_flutter.dart';
import 'package:mdi/mdi.dart';

enum PollQuestionRowTabs { SELECTION, RESULTS }

class PollQuestion extends StatefulWidget {
  final ProcessMetadata_Details_Question question;
  final ProcessModel process;
  final Function(int, int) onSetChoice;
  final int choice;
  final int questionIndex;
  final gradient = Rainbow(spectrum: [
    colorRedPale.withOpacity(0.9),
    colorBluePale,
    colorGreenPale,
  ], rangeStart: 0, rangeEnd: 1);

  PollQuestion(this.question, this.questionIndex, this.choice, this.process,
      this.onSetChoice);

  @override
  _PollQuestionState createState() => _PollQuestionState();
}

class _PollQuestionState extends State<PollQuestion> {
  Timer refreshCheck;
  PollQuestionRowTabs selectedTab = PollQuestionRowTabs.SELECTION;

  @override
  void initState() {
    widget.process.refreshResults();
    refreshCheck = Timer.periodic(Duration(minutes: 1), (_) {});
    super.initState();
  }

  bool get canVote {
    if (widget.process.hasVoted.value == true)
      return false;
    else if (!widget.process.startDate.hasValue)
      return false;
    else if (!widget.process.endDate.hasValue)
      return false;
    else if (widget.process.startDate.value.isAfter(DateTime.now()))
      return false;
    else if (widget.process.endDate.value.isBefore(DateTime.now()))
      return false;
    else if (widget.process.isInCensus.value != true) {
      // Allows widget.isInCensus to be null without breaking
      return false;
    }
    return true;
  }

  bool get resultsAvailable {
    if (!widget.process.results.hasValue)
      return false;
    else if (widget.process.results.value?.questions?.isEmpty ?? true)
      return false;
    return true;
  }

  @override
  void dispose() {
    if (refreshCheck is Timer) refreshCheck.cancel();

    super.dispose();
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    await onRefresh();
  }

  Future<void> onRefresh() {
    return widget.process
        .refreshResults()
        .catchError((err) => log(err)); // Values will refresh if needed
  }

  @override
  Widget build(context) {
    return EventualBuilder(
        notifiers: [
          widget.process.hasVoted,
          widget.process.isInCensus,
          widget.process.results,
          widget.process.startDate,
          widget.process.endDate
        ],
        builder: (context, _, __) {
          if (widget.question.type != "single-choice") {
            print(
                "ERROR: Question type not supported: " + widget.question.type);
            return buildError(
                getText(context, "main.questionTypeNotSupported"));
          }
          final resultsOk = resultsAvailable;
          final voteOk = canVote;

          return Column(
            children: <Widget>[
              Section(text: (widget.questionIndex + 1).toString()),
              buildQuestionTitle(widget.question, widget.questionIndex),
              buildTabSelect(resultsOk, voteOk),
              Column(
                children: buildQuestionOptions(resultsOk, voteOk),
                crossAxisAlignment: CrossAxisAlignment.start,
              ),
            ],
            crossAxisAlignment: CrossAxisAlignment.start,
          );
        });
  }

  onTabSelect(PollQuestionRowTabs tab) {
    setState(() {
      selectedTab = tab;
    });
  }

  refreshResultsOnSelect(PollQuestionRowTabs tab) {
    if (tab == PollQuestionRowTabs.RESULTS) {
      widget.process.refreshResults();
    }
  }

  Widget buildTabSelect(bool canSeeResults, canVote) {
    return ProcessNavigation(
      canVote,
      canSeeResults,
      widget.process.results.isLoading,
      onTabSelect: onTabSelect,
      onRefreshResults: refreshResultsOnSelect,
      selectedTab: selectedTab,
    );
  }

  List<Widget> buildQuestionOptions(bool resultsAvailable, bool canVote) {
    if (!resultsAvailable && !canVote) {
      return widget.question.voteOptions
          .map((voteOption) => buildPollOption(voteOption, disabled: true))
          .toList();
    } else if (selectedTab == PollQuestionRowTabs.SELECTION && canVote) {
      return widget.question.voteOptions
          .map((voteOption) => buildPollOption(voteOption))
          .toList();
    }

    // => (selectedTab == PollQuestionRowTabs.RESULTS)

    final results = widget.process.results.value;
    List<Widget> options = List<Widget>();
    int totalVotes = 0;
    int mostVotedCount = 0;
    int leastVotedCount =
        results.questions[widget.questionIndex].voteResults[0]?.votes ?? 0;
    results.questions[widget.questionIndex].voteResults.forEach((element) {
      totalVotes += element.votes;
      mostVotedCount =
          element.votes > mostVotedCount ? element.votes : mostVotedCount;
      leastVotedCount =
          element.votes < leastVotedCount ? element.votes : leastVotedCount;
    });
    widget.question.voteOptions.asMap().forEach((index, voteOption) {
      options.add(buildPollResultsOption(
          index, voteOption, totalVotes, mostVotedCount, leastVotedCount));
    });
    return options;
  }

  Widget buildPollOption(ProcessMetadata_Details_Question_VoteOption voteOption,
      {bool disabled = false}) {
    if (disabled) {
      return Chip(
        backgroundColor: colorLightGuide,
        padding: EdgeInsets.fromLTRB(10, 6, 10, 6),
        label: Text(
          voteOption.title[Globals.appState.currentLanguage],
          overflow: TextOverflow.ellipsis,
          maxLines: 5,
          style: TextStyle(
            fontSize: fontSizeSecondary,
            fontWeight: fontWeightRegular,
            color: colorDescription,
          ),
        ),
      ).withHPadding(paddingPage);
    }

    return ChoiceChip(
      backgroundColor: colorLightGuide,
      selectedColor: colorBlue,
      padding: EdgeInsets.fromLTRB(10, 6, 10, 6),
      label: Text(
        voteOption.title['default'],
        overflow: TextOverflow.ellipsis,
        maxLines: 5,
        style: TextStyle(
            fontSize: fontSizeSecondary,
            fontWeight: fontWeightRegular,
            color: widget.choice == voteOption.value
                ? Colors.white
                : colorDescription),
      ),
      selected: widget.choice == voteOption.value,
      onSelected: (bool selected) {
        if (selected) {
          widget.onSetChoice(widget.questionIndex, voteOption.value);
        }
      },
    ).withHPadding(paddingPage);
  }

  Widget buildPollResultsOption(
      int index,
      ProcessMetadata_Details_Question_VoteOption voteOption,
      int totalVotes,
      maxVotes,
      minVotes) {
    final results = widget.process.results.value;
    final myVotes =
        results.questions[widget.questionIndex]?.voteResults[index]?.votes ?? 0;
    final totalPerc = myVotes > 0 ? myVotes / totalVotes : 0.0;
    double relativePerc =
        myVotes - minVotes > 0 ? myVotes - minVotes / maxVotes - minVotes : 0.0;

    // Weight relative win/loss ratio between options based on max share of total votes
    relativePerc +=
        maxVotes > 0 ? (1 - (maxVotes / totalVotes)) * (1 - relativePerc) : 0;
    final myColor = totalVotes > 0
        ? widget.gradient[relativePerc]
        : colorBluePale.withOpacity(0.1);

    return LinearPercentIndicator(
      center: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Text(
                voteOption.title['default'],
                textAlign: TextAlign.left,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                    fontSize: fontSizeSecondary,
                    fontWeight: fontWeightSemiBold,
                    color: colorDescription),
              ).withLeftPadding(10),
            ),
            Text(
              myVotes == 1
                  ? "$myVotes " + getText(context, "main.vote").toLowerCase()
                  : "$myVotes " + getText(context, "main.votes").toLowerCase(),
              maxLines: 1,
              textAlign: TextAlign.right,
              overflow: TextOverflow.fade,
              // style: TextStyle(fontWeight: FontWeight.bold),
            ).withHPadding(20)
          ]),
      animation: false,
      alignment: MainAxisAlignment.start,
      backgroundColor: myColor.withOpacity(0.1),
      fillColor: Colors.transparent,
      linearGradient: LinearGradient(
          colors: [myColor, myColor.withOpacity(0.3)],
          begin: Alignment.topLeft),
      lineHeight: 30.0,
      percent: totalPerc,
      linearStrokeCap: LinearStrokeCap.butt,
    ).withVPadding(4).withHPadding(paddingBadge);
  }

  buildQuestionTitle(ProcessMetadata_Details_Question question, int index) {
    return ListItem(
      mainText: question.question['default'],
      mainTextMultiline: 3,
      secondaryText: question.description['default'],
      secondaryTextMultiline: 100,
      rightIcon: null,
    );
  }

  buildError(String error) {
    return ListItem(
      mainText: getText(context, "main.error") + " " + error,
      rightIcon: null,
      icon: FeatherIcons.alertCircle,
      purpose: Purpose.DANGER,
    );
  }

  Widget buildErrorScaffold(String error) {
    return Scaffold(
      body: Center(
        child: Text(
          getText(context, "main.error") + ":\n" + error,
          style: new TextStyle(fontSize: 26, color: Color(0xff888888)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class ProcessNavigation extends StatelessWidget {
  final PollQuestionRowTabs selectedTab;
  final Function(PollQuestionRowTabs) onTabSelect;
  final Function(PollQuestionRowTabs) onRefreshResults;
  final bool canVote;
  final bool canSeeResults;
  final bool refreshingResults;

  ProcessNavigation(this.canVote, this.canSeeResults, this.refreshingResults,
      {this.selectedTab, this.onTabSelect, this.onRefreshResults});

  @override
  Widget build(context) {
    return BottomNavigationBar(
      elevation: 0,
      backgroundColor: colorBaseBackground,
      onTap: (canVote && canSeeResults)
          ? (index) {
              if (index >= PollQuestionRowTabs.values.length)
                return;
              else if (onTabSelect is! Function) return;
              onTabSelect(PollQuestionRowTabs.values[index]);
            }
          : (index) {
              // if results are disabled, selecting results tab refreshes results, checks for new ones
              if (onRefreshResults is! Function) return;
              onRefreshResults(PollQuestionRowTabs.values[index]);
            },
      currentIndex:
          canVote ? selectedTab.index : PollQuestionRowTabs.RESULTS.index,
      items: <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          title: SizedBox.shrink(),
          icon: Icon(
            Mdi.voteOutline,
            size: 29.0,
            color: canVote ? null : Colors.grey[400],
          ),
        ),
        BottomNavigationBarItem(
          title: SizedBox.shrink(),
          icon: refreshingResults
              ? SpinnerCircular()
              : Icon(
                  FeatherIcons.pieChart,
                  size: 24.0,
                  color: canSeeResults ? null : Colors.grey[400],
                ),
        ),
      ],
    );
  }
}