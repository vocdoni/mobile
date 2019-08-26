import 'dart:convert';

import 'package:feather_icons_flutter/feather_icons_flutter.dart';
import "package:flutter/material.dart";
import 'package:flutter/services.dart';
import 'package:vocdoni/data/ent.dart';

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

class PollPageArgs {
  Ent ent;
  ProcessMetadata process;

  PollPageArgs({this.ent, this.process});
}

class PollPage extends StatefulWidget {
  @override
  _PollPageState createState() => _PollPageState();
}

class _PollPageState extends State<PollPage> {
  List<String> responses = [];

  @override
  void didChangeDependencies() {
    PollPageArgs args = ModalRoute.of(context).settings.arguments;

    ProcessMetadata process = args.process;
    process.details.questions.forEach((question) {
      responses.add("");
    });
    super.didChangeDependencies();
  }

  @override
  @override
  Widget build(context) {
    PollPageArgs args = ModalRoute.of(context).settings.arguments;
    Ent ent = args.ent;
    ProcessMetadata process = args.process;

    if (ent == null) return buildEmptyEntity(context);

    String headerUrl = process.details.headerImage == null
        ? fallbackImageUrlPoll
        : process.details.headerImage;
    return ScaffoldWithImage(
        headerImageUrl: headerUrl,
        headerTag: process.meta['processId'] + headerUrl,
        appBarTitle: "Poll",
        actionsBuilder: actionsBuilder,
        builder: Builder(
          builder: (ctx) {
            return SliverList(
              delegate: SliverChildListDelegate(
                  getScaffoldChildren(ctx, ent, process)),
            );
          },
        ));
  }

  List<Widget> actionsBuilder(BuildContext context) {
    PollPageArgs args = ModalRoute.of(context).settings.arguments;
    final Ent ent = args.ent;
    return [
      buildShareButton(context, ent),
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

  getScaffoldChildren(BuildContext context, Ent ent, ProcessMetadata process) {
    List<Widget> children = [];
    //children.add(buildTest());
    children.add(buildTitle(context, process));
    children.add(Summary(
      text: process.details.description['default'],
      maxLines: 5,
    ));
    children.add(buildRawItem(context, process));
    children.addAll(buildQuestions(context, process));

    return children;
  }

  buildTitle(BuildContext context, ProcessMetadata process) {
    String title = process.details.title['default'];
    return ListItem(
      mainTextTag: process.meta['processId'] + title,
      mainText: process.details.title['default'],
      secondaryText: process.meta['entityId'],
      isTitle: true,
      rightIcon: null,
      isBold: true,
    );
  }

  buildRawItem(BuildContext context, ProcessMetadata process) {
    return ListItem(
      icon: FeatherIcons.code,
      mainText: "Raw details",
      onTap: () {
        Navigator.pushNamed(context, "/entity/participation/process/raw",
            arguments: process);
      },
      disabled: true,
    );
  }

  buildShareButton(BuildContext context, Ent ent) {
    return BaseButton(
        leftIconData: FeatherIcons.share2,
        isSmall: false,
        style: BaseButtonStyle.NO_BACKGROUND_WHITE,
        onTap: () {
          Clipboard.setData(ClipboardData(text: ent.entitySummary.entityId));
          showMessage("Identity ID copied on the clipboard",
              context: context, purpose: Purpose.GUIDE);
        });
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

  List<Widget> buildQuestions(BuildContext ctx, ProcessMetadata process) {
    if (process.details.questions.length == 0) {
      return [buildError("No questions defined")];
    }

    List<Widget> items = new List<Widget>();
    int questionIndex = 0;
    for (ProcessMetadata_Details_Question question in process.details.questions) {
      items.addAll(buildQuestion(question, questionIndex));
      questionIndex++;
    }

    return items;
  }

  List<Widget> buildQuestion(ProcessMetadata_Details_Question question, int questionIndex) {
    List<Widget> items = new List<Widget>();

    if (question.type == "single-choice") {
      items.add(Section());
      items.add(buildQuestionTitle(question, questionIndex));

      List<Widget> options = new List<Widget>();
      question.voteOptions.forEach((voteOption) {
        options.add(Padding(
          padding: EdgeInsets.fromLTRB(paddingPage, 0, paddingPage, 0),
          child: ChoiceChip(
            backgroundColor: colorLightGuide,
            
            selectedColor: colorBlue,
            padding: EdgeInsets.fromLTRB(10, 6, 10, 6),
            label: Text(
              voteOption.title['default'],
              style: TextStyle(
                  fontSize: fontSizeSecondary,
                  fontWeight: fontWeightRegular,
                  color: responses[questionIndex] == voteOption.value
                      ? Colors.white
                      : colorDescription),
            ),
            selected: responses[questionIndex] == voteOption.value,
            onSelected: (bool selected) {
              if (selected) {
                setState(() {
                  responses[questionIndex] = voteOption.value;
                });
              }
            },
          ),
        ));
      });

      items.add(
        Column(
          children: options,
          crossAxisAlignment: CrossAxisAlignment.start,
        ),
      );
    } else {
      String questionType = question.type;
      buildError("Question type not supported: $questionType");
    }
    return items;
  }

  buildError(String error) {
    ListItem(
      mainText: "Error: $error",
      rightIcon: null,
      icon: FeatherIcons.alertCircle,
      purpose: Purpose.DANGER,
    );
  }

  buildQuestionTitle(ProcessMetadata_Details_Question question, int index) {
    return ListItem(
      mainText: index.toString() + ". " + question.question['default'],
      secondaryText: question.description['default'],
      secondaryTextMultiline: true,
      rightIcon: null,
    );
  }

  goBack(BuildContext ctx) {
    Navigator.pop(ctx, false);
  }
}
