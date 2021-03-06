import 'package:dvote/dvote.dart';
import 'package:dvote_crypto/dvote_crypto.dart';
import 'package:dvote_common/dvote_common.dart';
import 'package:dvote_common/widgets/baseButton.dart';
import 'package:dvote_common/widgets/loading-spinner.dart';
import 'package:dvote_common/widgets/toast.dart';
import 'package:dvote_common/widgets/topNavigation.dart';
import "package:flutter/material.dart";
import 'package:dvote_common/constants/colors.dart';
import 'package:vocdoni/data-models/account.dart';
import 'package:vocdoni/lib/globals.dart';
import 'package:vocdoni/lib/extensions.dart';
import 'package:vocdoni/view-modals/pattern-create-modal.dart';
import 'package:vocdoni/lib/i18n.dart';

class RecoveryMnemonicInput extends StatefulWidget {
  @override
  _RecoveryMnemonicInputState createState() => _RecoveryMnemonicInputState();
}

class _RecoveryMnemonicInputState extends State<RecoveryMnemonicInput> {
  final nameController = TextEditingController();
  final mnemonicController = TextEditingController();
  final nameNode = FocusNode();
  final mnemonicNode = FocusNode();
  bool restoring = false;

  @override
  void initState() {
    super.initState();
    Globals.analytics.trackPage("RecoveryMnemonicInput");

    Future.delayed(Duration(milliseconds: 100)).then((_) {
      FocusScope.of(context).requestFocus(nameNode);
    });
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is removed from the
    // widget tree.
    mnemonicController.dispose();
    super.dispose();
  }

  onSubmit(context) async {
    final alias = nameController.text.trim();
    final mnemonic = mnemonicController.text.trim();

    String err;
    if (alias.length == 0)
      err = getText(context, "main.enterANameForTheAccount");
    else if (mnemonic.length == 0)
      err = getText(context, "main.enterTheMnemonicWordsToRecover");
    else if (!RegExp(r"^([a-zA-Z]+ )+[a-zA-Z]+$").hasMatch(mnemonic))
      err = getText(context, "main.theMnemonicWordsYouEnteredAreNotValid");
    if (err is String) {
      showMessage(err, context: context, purpose: Purpose.WARNING);
      return;
    }

    final words = mnemonic.replaceAll(RegExp(r'[ ]+'), " ").split(" ");
    switch (words.length) {
      case 12:
      case 15:
      case 18:
      case 21:
      case 24:
        break;
      default:
        showMessage(
            getText(context, "main.theNumberOfWordsYouEnteredIsNotValid"),
            context: context,
            purpose: Purpose.WARNING);
        return;
    }

    try {
      final w = await EthereumWallet.fromMnemonic(mnemonic).privateKeyAsync;
      if (!(w is String)) throw Exception();
    } catch (err) {
      showMessage(getText(context, "error.theWordsYouEnteredAreNotValid"),
          context: context, purpose: Purpose.WARNING);
      return;
    }

    final patternEncryptionKey = await Navigator.push(
      context,
      MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => PatternCreateModal(canGoBack: true)),
    );
    Globals.analytics.trackPage("RecoverySuccess");

    if (patternEncryptionKey == null) {
      return;
    }

    try {
      setState(() => restoring = true);

      final newAccount = await AccountModel.fromMnemonic(
          mnemonic, alias, patternEncryptionKey);
      await Globals.accountPool.addAccount(newAccount);

      int newIndex = -1;
      for (int i = 0; i < Globals.accountPool.value.length; i++) {
        // TODO: Compare by identityId instead of rootPublicKey
        if (!Globals.accountPool.value[i].identity.hasValue)
          continue;
        else if (!pubKeysAreEqual(
            Globals.accountPool.value[i].identity.value.keys[0].rootPublicKey,
            newAccount.identity.value.keys[0].rootPublicKey)) continue;
        newIndex = i;
        break;
      }
      if (newIndex < 0)
        throw Exception("The new account can't be found on the pool");

      Globals.appState.selectAccount(newIndex);
      // Globals.appState.currentAccount?.cleanEphemeral();
      // Globals.accountPool.writeToStorage();   not needed => addAccount() does it

      showHomePage(context);
    } catch (err) {
      String text;
      setState(() => restoring = false);

      if (err.toString() ==
          "Exception: An account with this name already exists") {
        text = getText(context, "main.anAccountWithThisNameAlreadyExists");
      } else {
        text =
            getText(context, "main.anErrorOccurredWhileRestoringTheIdentity");
      }

      showAlert(text, title: getText(context, "main.error"), context: context);
    }
  }

  renderLoading() {
    return Center(
      child: Align(
        alignment: Alignment(0, -0.1),
        child: Container(
          constraints: BoxConstraints(maxWidth: 300, maxHeight: 300),
          color: Color(0x00ff0000),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(getText(context, "main.restoringIdentity"),
                  style: TextStyle(fontSize: 18)),
              SizedBox(height: 20),
              LoadingSpinner(),
            ],
          ),
        ),
      ),
    );
  }

  Widget renderOkButton(BuildContext context) {
    return BaseButton(
      maxWidth: double.infinity,
      purpose: Purpose.HIGHLIGHT,
      text: getText(context, "main.restoreIdentity"),
      onTap: () => onSubmit(context),
    ).withPadding(16);
  }

  @override
  Widget build(context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).requestFocus(new FocusNode());
      },
      child: Scaffold(
        appBar: TopNavigation(
          title: getText(context, "main.accountRecovery"),
        ),
        body: Builder(
          builder: (context) {
            if (restoring) return renderLoading();

            return ListView(children: <Widget>[
              Text(
                getText(context,
                    "main.toRestoreYourUserKeysEnterTheMnemonicWordsYouSavedDuringTheBackUp"),
                style: TextStyle(color: Colors.black45),
              ).withPadding(16),
              TextField(
                controller: nameController,
                focusNode: nameNode,
                style: TextStyle(fontSize: 18),
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  // border: InputBorder.none,
                  hintText: getText(context, "main.whatsYourName"),
                ),
              ).withHPadding(16),
              TextField(
                controller: mnemonicController,
                focusNode: mnemonicNode,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  // border: InputBorder.none,
                  hintText: getText(context, "main.mnemonicWords"),
                ),
              ).withPadding(16).withTopPadding(8),
              SizedBox(height: 16),
              renderOkButton(context),
            ]);
          },
        ),
      ),
    );
  }

  /////////////////////////////////////////////////////////////////////////////
  // LOCAL EVENTS
  /////////////////////////////////////////////////////////////////////////////

  showHomePage(BuildContext ctx) {
    // Replace all routes with /home on top
    Navigator.pushNamedAndRemoveUntil(ctx, "/home", (Route _) => false);
  }
}
