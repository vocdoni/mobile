import 'package:dvote/dvote.dart';
import 'package:dvote_common/constants/colors.dart';
import 'package:dvote_common/widgets/alerts.dart';
import 'package:dvote_common/widgets/loading-spinner.dart';
import 'package:dvote_common/widgets/toast.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:vocdoni/constants/settings.dart';
import 'package:vocdoni/data-models/account.dart';
import 'package:vocdoni/lib/extensions.dart';
import 'package:dvote_common/widgets/topNavigation.dart';
import 'package:dvote_common/widgets/unlockPattern/enterPin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vocdoni/lib/globals.dart';
import 'package:vocdoni/lib/i18n.dart';
import 'package:vocdoni/lib/logger.dart';
import 'package:vocdoni/lib/pattern.dart';
import 'package:vocdoni/views/onboarding/onboarding-backup-input.dart';

import '../../app-config.dart';

enum PinStep { READY, CONFIRMING, GENERATING }

class SetPinPage extends StatefulWidget {
  final String alias;
  final bool generateIdentity;

  SetPinPage(this.alias, {this.generateIdentity = true});

  @override
  _SetPinPageState createState() => _SetPinPageState();
}

class _SetPinPageState extends State<SetPinPage> {
  PinStep pinStep = PinStep.READY;
  final int numPinDigits = PIN_LENGTH;
  List<int> setPin = [];

  @override
  void initState() {
    super.initState();
    Globals.analytics.trackPage("SetPin");
  }

  @override
  Widget build(BuildContext context) {
    String firstMessage = "";
    String secondMessage = "";
    switch (pinStep) {
      case PinStep.READY:
        firstMessage = getText(context, "main.setAPinToProtectYourData") + ". ";
        secondMessage =
            getText(context, "main.youWillBeAskedThisPinForImportantThings") +
                ".";
        break;
      case PinStep.CONFIRMING:
        firstMessage = getText(context, "main.doubleCheckRepeatThePin") + ".";
        break;
      case PinStep.GENERATING:
        generateIdentity();
    }
    return Scaffold(
      appBar: TopNavigation(
        title: "",
        onBackButton: () => Navigator.pop(context, null),
      ),
      body: Builder(
        builder: (context) => pinStep == PinStep.GENERATING
            ? buildGenerating()
            : Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      firstMessage,
                      textAlign: TextAlign.left,
                      maxLines: 3,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: fontWeightLight,
                      ),
                    ).withHPadding(spaceCard).withBottomPadding(paddingPage),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      secondMessage,
                      style:
                          TextStyle(fontSize: 18, fontWeight: fontWeightLight),
                    ).withHPadding(spaceCard),
                  ),
                  Spacer(),
                  EnterPin(
                    key: foundation.Key(pinStep.toString()),
                    onPinStopped: pinStep == PinStep.READY
                        ? onFirstPassDone
                        : onSecondPassDone,
                    continueText: pinStep == PinStep.READY
                        ? getText(context, "main.confirm")
                        : null,
                    totalDigits: numPinDigits,
                    onPinHaptic: () {
                      HapticFeedback.mediumImpact();
                    },
                  ).withBottomPadding(40),
                ],
              ),
      ),
    );
  }

  void onFirstPassDone(BuildContext context, List<int> newPin) async {
    if (newPin.length != numPinDigits) {
      HapticFeedback.vibrate();
      final err = getText(context, "error.thereWasAProblemSettingThePin");
      showMessage(err, context: context, duration: 3, purpose: Purpose.DANGER);
      return;
    }

    HapticFeedback.vibrate();
    await Future.delayed(Duration(milliseconds: 500)).then((_) {});
    setState(() {
      setPin = newPin;
      pinStep = PinStep.CONFIRMING;
      Globals.analytics.trackPage("ConfirmPin");
    });
  }

  void onSecondPassDone(BuildContext context, List<int> pin) async {
    if (!foundation.listEquals(setPin, pin)) {
      HapticFeedback.vibrate();
      final msg = getText(context, "main.thePinsYouEnteredDoNotMatch");
      showMessage(msg, context: context, duration: 3, purpose: Purpose.DANGER);
      setState(() {
        pin = [];
        pinStep = PinStep.READY;
      });
      return;
    }
    HapticFeedback.vibrate();
    showMessage(getText(context, "main.yourPinHasBeenSet"),
        context: context, duration: 3, purpose: Purpose.GOOD);

    setState(() {
      pinStep = PinStep.GENERATING;
    });
  }

  void generateIdentity() async {
    final String pinEncryptionKey = pinToString(setPin);

    if (pinEncryptionKey == null) {
      return;
    }

    if (!widget.generateIdentity) {
      Navigator.pop(context, pinEncryptionKey); // Back to name page
      return;
    }

    try {
      final newAccount =
          await AccountModel.makeNew(widget.alias, pinEncryptionKey);
      newAccount.identity.value.version =
          AppConfig.packageInfo?.buildNumber ?? IDENTITY_VERSION;
      await Globals.accountPool.addAccount(newAccount);

      final newIndex = Globals.accountPool.value.indexWhere((account) =>
          account.identity.hasValue &&
          pubKeysAreEqual(account.identity.value.identityId,
              newAccount.identity.value.identityId));
      if (newIndex < 0)
        throw Exception("The new account can't be found on the pool");

      Globals.appState.selectAccount(newIndex);
      showNextPage(context);
    } on Exception catch (err) {
      logger.log("Error: $err");
      String text;
      setState(() {
        setPin = [];
        pinStep = PinStep.READY;
      });
      if (err.toString() ==
              "Exception: An account with this name already exists" ||
          err.toString() ==
              "Exception: main.anAccountWithThisNameAlreadyExists") {
        text = getText(context, "main.anAccountWithThisNameAlreadyExists");
      } else {
        text =
            getText(context, "main.anErrorOccurredWhileGeneratingTheIdentity");
      }
      Navigator.pop(context); // Back to name page
      showAlert(text, title: getText(context, "main.error"), context: context);
    }
  }

  buildGenerating() {
    return Center(
      child: Align(
        alignment: Alignment(0, 0),
        child: Container(
          constraints: BoxConstraints(maxWidth: 320, maxHeight: 400),
          color: Color(0x00ff0000),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(getText(context, "main.generatingIdentity"),
                  style: TextStyle(fontSize: 18)),
              SizedBox(height: 20),
              LoadingSpinner(),
            ],
          ),
        ),
      ),
    );
  }

  showNextPage(BuildContext ctx) {
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => OnboardingBackupInput(
            pinCache: pinToString(setPin),
          ),
        ),
        (Route _) => false);
  }
}
