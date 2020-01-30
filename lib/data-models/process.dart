import 'package:dvote/dvote.dart';
import 'package:vocdoni/constants/meta-keys.dart';
import 'package:vocdoni/data-models/account.dart';
import 'package:vocdoni/lib/errors.dart';
import 'package:vocdoni/lib/net.dart';
import 'package:vocdoni/lib/state-base.dart';
import 'package:vocdoni/lib/state-notifier.dart';
import 'package:vocdoni/lib/singletons.dart';
import 'package:vocdoni/lib/util.dart';

/// This class should be used exclusively as a global singleton via MultiProvider.
/// ProcessPoolModel tracks all the registered accounts and provides individual models that
/// can be listened to as well.
///
/// IMPORTANT: **Updates** on the own state must call `notifyListeners()` or use `setXXX()`.
/// Updates on the children models will be notified by the objects themselves if using StateContainer or StateNotifier.
///
class ProcessPoolModel extends StateNotifier<List<ProcessModel>>
    implements StatePersistable, StateRefreshable {
  ProcessPoolModel() {
    this.load(List<ProcessModel>());
  }

  // EXTERNAL DATA HANDLERS

  /// Read the global collection of all objects from the persistent storage
  @override
  Future<void> readFromStorage() async {
    if (!hasValue) this.load(List<ProcessModel>());

    try {
      this.setToLoading();
      final processList = globalProcessesPersistence.get();
      final processModelList = processList
          .where((processMeta) =>
              processMeta.meta[META_PROCESS_ID] is String &&
              processMeta.meta[META_ENTITY_ID] is String)
          .map((processMeta) => ProcessModel.fromMetadata(
              processMeta,
              processMeta.meta[META_PROCESS_ID],
              processMeta.meta[META_ENTITY_ID]))
          .cast<ProcessModel>()
          .toList();
      this.setValue(processModelList);
    } catch (err) {
      devPrint(err);
      this.setError("Cannot read the boot nodes list", keepPreviousValue: true);
      throw RestoreError("There was an error while accessing the local data");
    }
  }

  /// Write the given collection of all objects to the persistent storage
  @override
  Future<void> writeToStorage() async {
    if (!hasValue) this.load(List<ProcessModel>());

    try {
      final processList = this
          .value
          .where((processModel) =>
              processModel is ProcessModel && processModel.metadata.hasValue)
          .map((processModel) {
            // COPY STATE FIELDS INTO META
            processModel.metadata.value.meta[META_PROCESS_ID] =
                processModel.processId;
            processModel.metadata.value.meta[META_ENTITY_ID] =
                processModel.entityId;

            if (processModel.isInCensus.hasValue)
              processModel.metadata.value.meta[META_PROCESS_CENSUS_BELONGS] =
                  processModel.isInCensus.value ? "true" : "false";

            if (processModel.hasVoted.hasValue)
              processModel.metadata.value.meta[META_PROCESS_HAS_VOTED] =
                  processModel.hasVoted.value ? "true" : "false";

            if (processModel.censusSize.hasValue)
              processModel.metadata.value.meta[META_PROCESS_CENSUS_SIZE] =
                  processModel.censusSize.value.toString();

            return processModel.metadata.value;
          })
          .cast<ProcessMetadata>()
          .toList();
      await globalProcessesPersistence.writeAll(processList);
    } catch (err) {
      devPrint(err);
      throw PersistError("Cannot store the current state");
    }
  }

  @override
  Future<void> refresh([bool force = false]) async {
    if (!hasValue ||
        globalAppState.currentAccount == null ||
        !globalAppState.currentAccount.entities.hasValue) return;

    devPrint("Refreshing related user's processes");

    try {
      // Get a filtered list of the Entities of the current user
      final entityIds = globalAppState.currentAccount.entities.value
          .map((entity) => entity.reference.entityId)
          .toList();

      // This will call `setValue` on the individual models that are already within the pool.
      // No need to update the pool list itself.
      await Future.wait(this
          .value
          .where((processModel) => entityIds.contains(processModel.entityId))
          .map((processModel) => processModel.refresh(force))
          .toList());

      await this.writeToStorage();
    } catch (err) {
      devPrint(err);
    }
  }

  /// Removes the given feed from the pool and persists the new pool.
  Future<void> remove(List<ProcessModel> processModelsToRemove) async {
    if (!this.hasValue) throw Exception("The pool has no value yet");

    final updatedValue = this
        .value
        .where((poolProcess) {
          for (var rmModel in processModelsToRemove) {
            if (poolProcess.processId == rmModel.processId)
              return false; // get it out
          }

          return true; // keep it
        })
        .cast<ProcessModel>()
        .toList();
    this.setValue(updatedValue);

    await this.writeToStorage();
  }

  // HELPERS

  /// Returns the voting processes from the given entity
  List<ProcessModel> getFromEntityId(String entityId) {
    if (!this.hasValue) return [];

    return this
        .value
        .where((process) {
          if (!(process is ProcessModel) || !process.metadata.hasValue)
            return false;

          return process.metadata.value.meta[META_ENTITY_ID] == entityId;
        })
        .cast<ProcessModel>()
        .toList();
  }
}

/// ProcessModel encapsulates the relevant information of a Vocdoni Process.
/// This includes its metadata and the participation processes.
///
class ProcessModel implements StateRefreshable {
  final String processId;
  final String entityId;
  final String lang = "default";
  final StateNotifier<ProcessMetadata> metadata =
      StateNotifier<ProcessMetadata>();
  final StateNotifier<bool> isInCensus =
      StateNotifier<bool>().withFreshness(60 * 5);
  final StateNotifier<bool> hasVoted =
      StateNotifier<bool>().withFreshness(60 * 5);
  final StateNotifier<int> currentParticipants =
      StateNotifier<int>().withFreshness(60 * 5);
  final StateNotifier<int> censusSize =
      StateNotifier<int>().withFreshness(60 * 30);

  List<dynamic> choices = [];

  ProcessModel(this.processId, this.entityId,
      [ProcessMetadata metadata,
      bool isInCensus,
      bool hasVoted,
      int currentParticipants]) {
    if (metadata is ProcessMetadata) {
      // Ensure we can read it back
      metadata.meta[META_PROCESS_ID] = this.processId;
      metadata.meta[META_ENTITY_ID] = this.entityId;
      this.metadata.load(metadata);
    }
    if (isInCensus is bool) this.isInCensus.load(isInCensus);
    if (hasVoted is bool) this.hasVoted.load(hasVoted);
    if (currentParticipants is int)
      this.currentParticipants.load(currentParticipants);
  }

  ProcessModel.fromMetadata(
      ProcessMetadata metadata, this.processId, this.entityId) {
    // Ensure we can read it back
    metadata.meta[META_PROCESS_ID] = this.processId;
    metadata.meta[META_ENTITY_ID] = this.entityId;

    this.metadata.load(metadata);

    switch (this.metadata.value.meta[META_PROCESS_CENSUS_BELONGS]) {
      case "true":
        this.isInCensus.load(true);
        break;
      case "false":
        this.isInCensus.load(false);
        break;
    }

    switch (this.metadata.value.meta[META_PROCESS_HAS_VOTED]) {
      case "true":
        this.isInCensus.load(true);
        break;
      case "false":
        this.isInCensus.load(false);
        break;
    }

    if (this.metadata.value.meta[META_PROCESS_CENSUS_SIZE] is String) {
      final strValue =
          this.metadata.value.meta[META_PROCESS_CENSUS_SIZE] ?? "0";
      final newSize = int.tryParse(strValue) ?? 0;
      this.censusSize.load(newSize);
    }
  }

  @override
  Future<void> refresh([bool force = false]) {
    devPrint("Refreshing process ${this.processId}");

    return Future.wait([
      refreshMetadata(force),
      refreshIsInCensus(force),
      refreshHasVoted(force),
      refreshCurrentParticipants(force),
      refreshCensusSize(force),
    ]);
  }

  Future<void> refreshMetadata([bool force = false]) async {
    if (!force && this.metadata.isFresh)
      return;
    else if (!force &&
        this.metadata.isLoading &&
        !this.metadata.isLoadingStalled) return;

    devPrint("- Refreshing process metadata [${this.processId}]");

    // TODO: Don't refetch if the IPFS hash is the same

    final dvoteGw = getDVoteGateway();
    final Web3Gateway web3Gw = getWeb3Gateway();

    try {
      this.metadata.setToLoading();
      final newMetadata =
          await getProcessMetadata(this.processId, dvoteGw, web3Gw);
      newMetadata.meta[META_PROCESS_ID] =
          this.processId; // Ensure we can read it back
      newMetadata.meta[META_ENTITY_ID] = this.entityId;

      devPrint("- Refreshing process metadata [DONE] [${this.processId}]");

      this.metadata.setValue(newMetadata);
    } catch (err) {
      devPrint(
          "- Refreshing process metadata [ERROR: $err] [${this.processId}]");

      this.metadata.setError("Could not fetch the process details");
    }
  }

  Future<void> refreshIsInCensus([bool force = false]) async {
    if (!this.metadata.hasValue)
      return;
    else if (!force && this.isInCensus.isFresh)
      return;
    else if (!force && this.isInCensus.isLoading)
      return;
    else if (this.isInCensus.value == true)
      return; // we should never be excluded from a census once within

    devPrint("- Refreshing process isInCensus [${this.processId}]");

    final dvoteGw = getDVoteGateway();

    final currentAccount = globalAppState.currentAccount;
    if (!(currentAccount is AccountModel)) return;

    try {
      this.isInCensus.setToLoading();

      final base64Claim =
          await digestHexClaim(currentAccount.identity.value.keys[0].publicKey);

      final proof = await generateProof(
          this.metadata.value.census.merkleRoot, base64Claim, dvoteGw);
      if (!(proof is String) || !proof.startsWith("0x")) {
        this.isInCensus.setError("You are not part of the census");
        return;
      }

      final emptyProofRegexp =
          RegExp(r"^0x[0]+$", caseSensitive: false, multiLine: false);

      if (emptyProofRegexp.hasMatch(proof)) {
        this.isInCensus.setValue(false); // 0x0000000000.....
        return;
      }

      final valid = await checkProof(
          this.metadata.value.census.merkleRoot, base64Claim, proof, dvoteGw);

      devPrint("- Refreshing process isInCensus [DONE] [${this.processId}]");

      this.isInCensus.setValue(valid);
    } catch (err) {
      devPrint(
          "- Refreshing process isInCensus [ERROR: $err] [${this.processId}]");

      this.isInCensus.setError("Could not check the census");
    }
  }

  Future<void> refreshHasVoted([bool force = false]) async {
    if (!force && this.hasVoted.isFresh)
      return;
    else if (!force && this.hasVoted.isLoading)
      return;
    else if (!this.hasVoted.hasError && this.hasVoted.value == true) return;

    devPrint("- Refreshing process hasVoted [${this.processId}]");

    final currentAccount = globalAppState.currentAccount;
    if (!(currentAccount is AccountModel)) return;

    try {
      this.hasVoted.setToLoading();
      final String pollNullifier = getPollNullifier(
          globalAppState.currentAccount.identity.value.keys[0].address,
          this.processId);

      final dvoteGw = getDVoteGateway();
      final success =
          await getEnvelopeStatus(this.processId, pollNullifier, dvoteGw)
              .catchError((_) {});

      if (success is bool) {
        devPrint("- Refreshing process hasVoted [DONE] [${this.processId}]");

        this.hasVoted.setValue(success);
      } else {
        devPrint("- Refreshing process hasVoted [NO BOOL] [${this.processId}]");

        this.hasVoted.setError("Could not check the process status");
      }
    } catch (err) {
      devPrint(
          "- Refreshing process hasVoted [ERROR: $err] [${this.processId}]");

      this.hasVoted.setError("Could not check the vote status");
    }
  }

  Future<void> refreshCensusSize([bool force = false]) {
    if (!this.metadata.hasValue) return null;

    devPrint("- Refreshing process censusSize [${this.processId}]");

    final dvoteGw = getDVoteGateway();

    this.censusSize.setToLoading();
    return getCensusSize(this.metadata.value.census.merkleRoot, dvoteGw)
        .then((size) {
      devPrint("- Refreshing process censusSize [DONE $size] [${this.processId}]");

      return this.censusSize.setValue(size);
    }).catchError((err) {
      devPrint(
          "- Refreshing process censusSize [ERROR: $err] [${this.processId}]");

      this.censusSize.setError("Could not check the census size");
    });
  }

  Future<void> refreshCurrentParticipants([bool force = false]) {
    if (!this.metadata.hasValue)
      return Future.value();
    else if (!force && this.currentParticipants.isFresh)
      return Future.value();
    else if (!force && this.currentParticipants.isLoading)
      return Future.value();

    devPrint("- Refreshing process currentParticipants [${this.processId}]");

    final dvoteGw = getDVoteGateway();

    this.currentParticipants.setToLoading();
    return getEnvelopeHeight(this.processId, dvoteGw).then((numVotes) {
      devPrint(
          "- Refreshing process currentParticipants [DONE] [${this.processId}]");

      return this.currentParticipants.setValue(numVotes);
    }).catchError((err) {
      devPrint(
          "- Refreshing process currentParticipants [ERROR: $err] [${this.processId}]");

      this.currentParticipants.setError("Could not check the census size");
    });
  }

  // GETTERS

  double get currentParticipation {
    if (!this.censusSize.hasValue || !this.currentParticipants.hasValue)
      return 0.0;
    else if (this.censusSize.value <= 0) return 0.0;

    return this.currentParticipants.value *
        100.0 /
        this.censusSize.value.toDouble();
  }

  DateTime get startDate {
    if (!this.metadata.hasValue || !globalAppState.referenceBlock.hasValue)
      return null;

    final remainingDuration =
        globalAppState.getDurationUntilBlock(this.metadata.value.startBlock);
    if (remainingDuration is Duration)
      return DateTime.now().add(remainingDuration);
    return null;
  }

  DateTime get endDate {
    if (!this.metadata.hasValue || !globalAppState.referenceBlock.hasValue)
      return null;

    final remainingDuration = globalAppState.getDurationUntilBlock(
        this.metadata.value.startBlock + this.metadata.value.numberOfBlocks);
    if (remainingDuration is Duration)
      return DateTime.now().add(remainingDuration);
    return null;
  }
}