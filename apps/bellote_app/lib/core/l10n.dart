import 'package:bellote_engine/bellote_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/room_info.dart';

class L10n {
  const L10n(this.locale);

  final Locale locale;

  static L10n of(BuildContext context) =>
      Localizations.of<L10n>(context, L10n) ?? const L10n(Locale('fr'));

  bool get isFr => locale.languageCode == 'fr';

  String t(String key, [Map<String, Object?>? args]) {
    var value = (isFr ? _fr : _en)[key] ?? (isFr ? _en : _fr)[key] ?? key;
    if (args != null) {
      for (final entry in args.entries) {
        value = value.replaceAll('{${entry.key}}', '${entry.value}');
      }
    }
    return value;
  }

  String seatName(RoomInfo? room, int seat, {int? me}) {
    if (me != null && seat == me) return t('you');
    final player = room?.seatAt(seat);
    if (player == null) return t('emptySeat');
    return player.name;
  }

  String teamName(int team, int myTeam) =>
      team == myTeam ? t('teamUs') : t('teamThem');

  String rankLabel(Rank rank) => switch (rank) {
        Rank.seven => '7',
        Rank.eight => '8',
        Rank.nine => '9',
        Rank.ten => '10',
        Rank.jack => isFr ? 'V' : 'J',
        Rank.queen => isFr ? 'D' : 'Q',
        Rank.king => isFr ? 'R' : 'K',
        Rank.ace => isFr ? 'A' : 'A',
      };

  String suitName(Suit suit) => switch (suit) {
        Suit.spades => t('suitSpades'),
        Suit.hearts => t('suitHearts'),
        Suit.diamonds => t('suitDiamonds'),
        Suit.clubs => t('suitClubs'),
      };

  String cardLabel(Card card) => '${rankLabel(card.rank)}${card.suit.symbol}';

  String contractLabel(Contract? contract) {
    if (contract == null) return t('noContract');
    final base = contract.isCapot ? t('capot') : '${contract.amount}';
    final counter = switch (contract.counter) {
      CounterState.none => '',
      CounterState.countered => ' ×2',
      CounterState.surcountered => ' ×4',
    };
    return '$base ${contract.trump.symbol}$counter';
  }

  String formatLabel(String format) => switch (format) {
        'bestOf5' => t('bestOf5'),
        'singleSet' => t('singleSet'),
        _ => t('bestOf3'),
      };

  String eventText(GameEvent event, RoomInfo? room, int? me) {
    final data = event.data;
    final seat = data['seat'] is int ? data['seat'] as int : null;
    final winner = data['winnerSeat'] is int ? data['winnerSeat'] as int : null;
    final name = seat == null ? '' : seatName(room, seat, me: me);
    final winnerName = winner == null ? '' : seatName(room, winner, me: me);
    switch (event.type) {
      case 'deal_started':
        return t('eventDealStarted', {
          'dealer': seatName(room, data['dealerSeat'] as int? ?? 0, me: me),
        });
      case 'redeal':
        return data['reason'] == 'all_pass'
            ? t('eventRedealAllPass')
            : t('eventRedealSuit');
      case 'pass':
        return t('eventPass', {'seat': name});
      case 'bid':
        return t('eventBid', {
          'seat': name,
          'amount': data['amount'],
          'suit': _suitSymbol(data['suit']),
        });
      case 'capot':
        return t('eventCapot', {
          'seat': name,
          'suit': _suitSymbol(data['suit']),
        });
      case 'counter':
        return t('eventCounter', {'seat': name});
      case 'surcounter':
        return t('eventSurcounter', {'seat': name});
      case 'contract':
        return t('eventContract', {
          'seat': name,
          'amount': data['amount'] ?? t('capot'),
          'suit': _suitSymbol(data['trump']),
        });
      case 'play':
        return t('eventPlay', {
          'seat': name,
          'card': _cardFromData(data['card']),
        });
      case 'trick':
        return t('eventTrick', {'seat': winnerName, 'points': data['points']});
      case 'belote':
        return t('eventBelote', {'seat': name});
      case 'rebelote':
        return t('eventRebelote', {'seat': name});
      case 'early_stop':
        return data['reason'] == 'capot_defense_trick'
            ? t('eventEarlyStopCapot')
            : t('eventEarlyStopContract');
      case 'deal_end':
        return t('eventDealEnd');
      case 'set_end':
        return t('eventSetEnd', {
          'team': teamName(data['winner'] as int? ?? 0, (me ?? 0) % 2),
        });
      case 'match_end':
        return t('eventMatchEnd', {
          'team': teamName(data['winner'] as int? ?? 0, (me ?? 0) % 2),
        });
      case 'set_tie_replay':
        return t('eventSetTie');
      default:
        return event.type;
    }
  }

  String _suitSymbol(Object? suitName) {
    if (suitName is! String || suitName.isEmpty) return '';
    try {
      return Suit.fromName(suitName).symbol;
    } catch (_) {
      return suitName;
    }
  }

  String _cardFromData(Object? id) {
    if (id is! String) return '?';
    try {
      return cardLabel(Card.parse(id));
    } catch (_) {
      return id;
    }
  }

  String errorText(String? code) {
    if (code == null || code.isEmpty) return t('errorUnknown');
    final key = _errorKeys[code];
    if (key == null) return t('errorUnknown');
    return t(key);
  }

  static const Map<String, String> _errorKeys = {
    'connection_failed': 'connectionError',
    'room_not_found': 'errorRoomNotFound',
    'room_full': 'errorRoomFull',
    'room_started': 'errorRoomStarted',
    'invalid_room_code': 'errorInvalidRoomCode',
    'invalid_name': 'errorInvalidName',
    'host_only': 'errorHostOnly',
    'not_your_turn': 'errorNotYourTurn',
    'illegal_card': 'errorIllegalCard',
    'bid_must_be_higher': 'errorBidMustBeHigher',
    'invalid_bid_amount': 'errorInvalidBidAmount',
    'bids_blocked_by_counter': 'errorBidsBlocked',
    'auction_closed': 'errorAuctionClosed',
    'no_counter_to_surcounter': 'errorNoCounter',
    'only_bidding_team_can_surcounter': 'errorOnlyBiddingTeam',
    'not_enough_players': 'errorNotEnoughPlayers',
    'too_fast': 'errorTooFast',
    'internal_error': 'errorInternal',
    'not_in_room': 'errorNotInRoom',
    'game_not_started': 'errorGameNotStarted',
    'game_already_started': 'errorGameNotStarted',
    'deal_not_complete': 'errorDealNotComplete',
    'invalid_message': 'errorInvalidMessage',
    'invalid_card': 'errorInvalidCard',
    'cannot_counter_own_team': 'errorCannotCounterOwnTeam',
    'already_countered': 'errorAlreadyCountered',
    'no_bid_to_counter': 'errorNoBidToCounter',
    'invalid_token': 'errorInvalidToken',
    'session_closed': 'errorSessionClosed',
    'already_in_room': 'errorAlreadyInRoom',
    'not_playing_phase': 'errorNotPlayingPhase',
    'not_bidding_phase': 'errorNotBiddingPhase',
    'card_not_in_hand': 'errorCardNotInHand',
    'not_a_bot': 'errorUnknown',
    'unknown_message': 'errorUnknown',
  };

  static const Map<String, String> _fr = {
    'appTitle': 'Belote Contrée',
    'tagline': 'La belote tunisienne, entre amis',
    'playOnline': 'Jouer en ligne',
    'createRoom': 'Créer une partie',
    'joinRoom': 'Rejoindre',
    'resumeGame': 'Reprendre la partie',
    'settings': 'Réglages',
    'rules': 'Règles',
    'language': 'Langue',
    'french': 'Français',
    'english': 'Anglais',
    'playerName': 'Votre nom',
    'serverUrl': 'Adresse du serveur',
    'save': 'Enregistrer',
    'cancel': 'Annuler',
    'close': 'Fermer',
    'back': 'Retour',
    'copy': 'Copier',
    'copied': 'Code copié',
    'roomCode': 'Code de la partie',
    'waitingPlayers': 'En attente de joueurs',
    'playersLabel': 'Joueurs',
    'addBot': 'Ajouter un bot',
    'removeBot': 'Retirer',
    'startGame': 'Commencer',
    'leaveRoom': 'Quitter la salle',
    'leaveGame': 'Quitter la partie',
    'you': 'Vous',
    'dealer': 'Donneur',
    'bot': 'Bot',
    'emptySeat': 'Siège libre',
    'swapSeatsHint':
        'Touchez un siège puis un autre pour échanger les joueurs et composer les équipes.',
    'offline': 'Hors ligne',
    'reconnecting': 'Reconnexion…',
    'waiting': 'En attente',
    'yourTurnBid': 'À vous de parler',
    'yourTurnPlay': 'À vous de jouer',
    'waitingFor': 'En attente de {name}',
    'bidding': 'Enchères',
    'playing': 'Jeu',
    'pass': 'Passer',
    'bid': 'Annoncer',
    'capot': 'Capot',
    'counter': 'Contrer',
    'surcounter': 'Surcontrer',
    'contre': 'Contré',
    'surcontre': 'Surcontré',
    'trump': 'Atout',
    'contract': 'Contrat',
    'points': 'Points',
    'set': 'Set {number}',
    'setTarget': 'Objectif {target}',
    'setWon': 'Set remporté',
    'belle': 'Belle',
    'matchWon': 'Victoire !',
    'matchLost': 'Défaite',
    'dealResult': 'Résultat de la donne',
    'contractMade': 'Contrat réussi',
    'contractFailed': 'Contrat chuté',
    'nextDeal': 'Donne suivante',
    'nextDealAuto': 'La donne suivante démarre automatiquement…',
    'backToMenu': 'Retour au menu',
    'rawPoints': 'Points bruts',
    'roundedPoints': 'Points arrondis',
    'belote': 'Belote',
    'dixDeDer': 'Dix de der',
    'earlyStop': 'Arrêt anticipé',
    'earlyStopContract': 'Le contrat ne peut plus être réussi.',
    'earlyStopCapot': 'La défense a remporté un pli : capot raté.',
    'declareBelote': 'Déclarer Belote',
    'playWithoutBelote': 'Jouer sans déclarer',
    'playWithBelote': 'Jouer et dire « Belote »',
    'beloteAvailable': 'Belote en main',
    'chat': 'Discussion',
    'send': 'Envoyer',
    'typeMessage': 'Votre message…',
    'connectionError': 'Connexion impossible. Vérifiez l’adresse du serveur.',
    'errorRoomNotFound': 'Salle introuvable.',
    'errorRoomFull': 'La salle est complète.',
    'errorRoomStarted': 'La partie a déjà commencé.',
    'errorInvalidCode': 'Code de partie invalide.',
    'errorInvalidName': 'Nom invalide.',
    'errorHostOnly': 'Seul l’hôte peut faire cela.',
    'errorNotYourTurn': 'Ce n’est pas votre tour.',
    'errorIllegalCard': 'Cette carte n’est pas autorisée.',
    'errorBidMustBeHigher': 'L’enchère doit être supérieure.',
    'errorInvalidBidAmount': 'Montant d’enchère invalide.',
    'errorBidsBlocked': 'Les enchères sont bloquées par le contre.',
    'errorAuctionClosed': 'Les enchères sont terminées.',
    'errorNoCounter': 'Aucun contre à surcontrer.',
    'errorOnlyBiddingTeam': 'Seule l’équipe annonceuse peut surcontrer.',
    'errorNotEnoughPlayers': 'Il manque des joueurs.',
    'errorTooFast': 'Trop d’actions, patientez un instant.',
    'errorInternal': 'Erreur interne du serveur.',
    'errorNotInRoom': 'Vous n’êtes pas dans une salle.',
    'errorGameNotStarted': 'La partie n’a pas commencé.',
    'errorDealNotComplete': 'La donne n’est pas terminée.',
    'errorInvalidMessage': 'Message invalide.',
    'errorInvalidCard': 'Carte invalide.',
    'errorCannotCounterOwnTeam': 'Impossible de contrer votre propre contrat.',
    'errorAlreadyCountered': 'Le contrat est déjà contré.',
    'errorNoBidToCounter': 'Aucune annonce à contrer.',
    'errorInvalidRoomCode': 'Code de partie invalide.',
    'errorInvalidToken': 'Session expirée.',
    'errorSessionClosed':
        'Vous avez quitté cette partie : impossible d’y revenir.',
    'errorAlreadyInRoom': 'Vous êtes déjà dans une salle.',
    'errorNotPlayingPhase': 'La phase de jeu n’a pas commencé.',
    'errorNotBiddingPhase': 'La phase d’enchères est terminée.',
    'errorCardNotInHand': 'Cette carte n’est pas dans votre main.',
    'errorUnknown': 'Une erreur est survenue.',
    'rulesTitle': 'Règles essentielles',
    'rulesBody': '32 cartes, 4 joueurs, 2 équipes.\n\n'
        'Enchères de 90 à 180 par paliers de 10, ou capot. '
        'Le capot est supérieur à tout et ne peut être contré. '
        'Trois passes après la dernière annonce clôturent les enchères.\n\n'
        'Le joueur à droite du donneur parle et entame. '
        'On doit fournir la couleur demandée. '
        'À l’atout, il faut monter si possible, même sur son partenaire. '
        'Hors atout, couper ou surcouper selon les règles. '
        'Un joueur bloqué à l’atout doit jouer un atout.\n\n'
        'Belote-rebelote : 20 points, à déclarer une seule fois en jouant le roi ou la dame d’atout. '
        'La rebelote se valide ensuite automatiquement. '
        'Dix de der : 10 points.\n\n'
        'Contrat réussi si les points arrondis de l’attaque atteignent le montant. '
        'Contrat chuté : 160 points à la défense. '
        'Contré : 320, surcontré : 640. '
        'Capot demandé : 500. Capot non demandé : 250.\n\n'
        'La donne s’arrête dès que le contrat devient mathématiquement impossible.',
    'bestOf3': 'Meilleur des 3 sets',
    'bestOf5': 'Meilleur des 5 sets',
    'singleSet': 'Set unique à 3000',
    'format': 'Format',
    'suitSpades': 'Pique',
    'suitHearts': 'Cœur',
    'suitDiamonds': 'Carreau',
    'suitClubs': 'Trèfle',
    'teamUs': 'Nous',
    'teamThem': 'Eux',
    'noContract': 'Aucun contrat',
    'pointsAbbr': 'pts',
    'cards': 'cartes',
    'tricks': 'plis',
    'lastTrick': 'Dernier pli',
    'log': 'Journal',
    'waitingHost': 'En attente du lancement par l’hôte…',
    'roomCreated': 'Salle créée',
    'joinHint': 'Entrez le code à 5 caractères partagé par l’hôte.',
    'nameHint': 'Votre prénom',
    'serverHint': 'ws://192.168.1.10:8080/ws',
    'autoPlay': 'Joué automatiquement',
    'turnTimeout': 'Temps écoulé : coup automatique.',
    'contractBy': 'Contrat de {name}',
    'attack': 'Attaque',
    'defense': 'Défense',
    'setScores': 'Score du set',
    'matchScores': 'Sets gagnés',
    'dealNumber': 'Donne {number}',
    'dealerShort': 'D',
    'waitingConnection': 'Connexion au serveur…',
    'connecting': 'Connexion…',
    'spectator': 'Spectateur',
    'earlyStoppedShort': 'Arrêt anticipé',
    'eventDealStarted': 'Donne distribuée par {dealer}',
    'eventRedealAllPass': 'Quatre passes : nouvelle donne',
    'eventRedealSuit': '7 ou 8 cartes d’une couleur : redistribution',
    'eventPass': '{seat} passe',
    'eventBid': '{seat} annonce {amount} {suit}',
    'eventCapot': '{seat} demande le capot à {suit}',
    'eventCounter': '{seat} contre',
    'eventSurcounter': '{seat} surcontre',
    'eventContract': 'Contrat : {amount} {suit} par {seat}',
    'eventPlay': '{seat} joue {card}',
    'eventTrick': '{seat} remporte le pli ({points} pts)',
    'eventBelote': '{seat} annonce Belote',
    'eventRebelote': '{seat} annonce Rebelote',
    'eventEarlyStopContract': 'Contrat devenu impossible : arrêt',
    'eventEarlyStopCapot': 'Capot raté : arrêt',
    'eventDealEnd': 'Fin de la donne',
    'eventSetEnd': 'Set remporté par {team}',
    'eventMatchEnd': 'Partie remportée par {team}',
    'eventSetTie': 'Égalité au seuil : nouvelle donne',
    'gameCode': 'Code',
    'leaveConfirmTitle': 'Quitter la partie ?',
    'leaveConfirmBody':
        'Votre siège sera repris par un bot. Vous ne pourrez plus revenir dans cette partie.',
    'confirmLeave': 'Quitter',
    'stay': 'Rester',
    'notYourTurn': 'Patientez…',
    'tapCardToPlay': 'Touchez une carte surlignée',
    'bidHint': 'Choisissez un montant et un atout',
    'capotHint': 'Annonce suprême : 8 plis obligatoires',
    'chatEmpty': 'Aucun message pour le moment.',
    'chatSendError': 'Impossible d’envoyer le message.',
    'serverTime': 'Serveur',
    'version': 'Version 0.1',
    'pointsWon': '{points} pts',
    'tricksWon': '{count} plis',
    'outOfTurnAction': 'Action hors tour disponible',
    'counterAvailable': 'Vous pouvez contrer',
    'surcounterAvailable': 'Vous pouvez surcontrer',
    'waitingForHost': 'En attente de l’hôte',
    'readyToStart': 'Tous les joueurs sont prêts',
    'seatNumber': 'Siège {number}',
    'host': 'Hôte',
    'disconnected': 'Déconnecté',
    'autoControlled': 'Bot temporaire',
    'formatHint': 'Choisissez le format de la partie',
    'saveSettings': 'Enregistrer les réglages',
    'settingsSaved': 'Réglages enregistrés',
    'languageFrench': 'Français',
    'languageEnglish': 'English',
    'resumeHint': 'Une session récente est disponible.',
    'amount': 'Montant',
    'suit': 'Couleur',
    'seeTable': 'Voir la table',
    'newDealSoon': 'Nouvelle donne dans un instant…',
    'waitingPlayersCount': '{count}/4 joueurs',
    'noBidsYet': 'Aucune annonce',
    'matchEndTitle': 'Fin de la partie',
    'waitingTurn': 'Au tour de {name}',
    'beloteHint':
        'Jouez le roi ou la dame d’atout pour déclarer la belote (une seule fois).',
    'clearSession': 'Oublier la session',
    'menu': 'Menu',
    'setsWonShort': '{count} set(s)',
    'yourTurn': 'À vous',
    'roomInfo': 'Salle {code}',
    'copyCode': 'Copier le code',
    'shareCode': 'Partagez ce code avec vos amis.',
    'leaveLobbyBody': 'Vous quitterez la salle et libérerez votre siège.',
    'capotOnly': 'Capot seulement',
  };

  static const Map<String, String> _en = {
    'appTitle': 'Contrée Belote',
    'tagline': 'Tunisian belote, with friends',
    'playOnline': 'Play online',
    'createRoom': 'Create a game',
    'joinRoom': 'Join',
    'resumeGame': 'Resume game',
    'settings': 'Settings',
    'rules': 'Rules',
    'language': 'Language',
    'french': 'French',
    'english': 'English',
    'playerName': 'Your name',
    'serverUrl': 'Server address',
    'save': 'Save',
    'cancel': 'Cancel',
    'close': 'Close',
    'back': 'Back',
    'copy': 'Copy',
    'copied': 'Code copied',
    'roomCode': 'Room code',
    'waitingPlayers': 'Waiting for players',
    'playersLabel': 'Players',
    'addBot': 'Add a bot',
    'removeBot': 'Remove',
    'startGame': 'Start game',
    'leaveRoom': 'Leave room',
    'leaveGame': 'Leave game',
    'you': 'You',
    'dealer': 'Dealer',
    'bot': 'Bot',
    'emptySeat': 'Open seat',
    'swapSeatsHint':
        'Tap a seat, then another seat to swap players and set up the teams.',
    'offline': 'Offline',
    'reconnecting': 'Reconnecting…',
    'waiting': 'Waiting',
    'yourTurnBid': 'Your turn to bid',
    'yourTurnPlay': 'Your turn to play',
    'waitingFor': 'Waiting for {name}',
    'bidding': 'Bidding',
    'playing': 'Play',
    'pass': 'Pass',
    'bid': 'Bid',
    'capot': 'Capot',
    'counter': 'Double',
    'surcounter': 'Redouble',
    'contre': 'Doubled',
    'surcontre': 'Redoubled',
    'trump': 'Trump',
    'contract': 'Contract',
    'points': 'Points',
    'set': 'Set {number}',
    'setTarget': 'Target {target}',
    'setWon': 'Set won',
    'belle': 'Decider',
    'matchWon': 'Victory!',
    'matchLost': 'Defeat',
    'dealResult': 'Deal result',
    'contractMade': 'Contract made',
    'contractFailed': 'Contract failed',
    'nextDeal': 'Next deal',
    'nextDealAuto': 'Next deal starts automatically…',
    'backToMenu': 'Back to menu',
    'rawPoints': 'Raw points',
    'roundedPoints': 'Rounded points',
    'belote': 'Belote',
    'dixDeDer': 'Last trick',
    'earlyStop': 'Early stop',
    'earlyStopContract': 'The contract can no longer be made.',
    'earlyStopCapot': 'The defense won a trick: capot failed.',
    'declareBelote': 'Declare Belote',
    'playWithoutBelote': 'Play without declaring',
    'playWithBelote': 'Play and say “Belote”',
    'beloteAvailable': 'Belote in hand',
    'chat': 'Chat',
    'send': 'Send',
    'typeMessage': 'Your message…',
    'connectionError': 'Connection failed. Check the server address.',
    'errorRoomNotFound': 'Room not found.',
    'errorRoomFull': 'The room is full.',
    'errorRoomStarted': 'The game has already started.',
    'errorInvalidCode': 'Invalid room code.',
    'errorInvalidName': 'Invalid name.',
    'errorHostOnly': 'Only the host can do that.',
    'errorNotYourTurn': 'It is not your turn.',
    'errorIllegalCard': 'That card is not allowed.',
    'errorBidMustBeHigher': 'The bid must be higher.',
    'errorInvalidBidAmount': 'Invalid bid amount.',
    'errorBidsBlocked': 'Bidding is blocked by the double.',
    'errorAuctionClosed': 'Bidding is over.',
    'errorNoCounter': 'No double to redouble.',
    'errorOnlyBiddingTeam': 'Only the bidding team can redouble.',
    'errorNotEnoughPlayers': 'Not enough players.',
    'errorTooFast': 'Too many actions, please wait.',
    'errorInternal': 'Internal server error.',
    'errorNotInRoom': 'You are not in a room.',
    'errorGameNotStarted': 'The game has not started.',
    'errorDealNotComplete': 'The deal is not over.',
    'errorInvalidMessage': 'Invalid message.',
    'errorInvalidCard': 'Invalid card.',
    'errorCannotCounterOwnTeam': 'You cannot double your own contract.',
    'errorAlreadyCountered': 'The contract is already doubled.',
    'errorNoBidToCounter': 'No bid to double.',
    'errorInvalidRoomCode': 'Invalid room code.',
    'errorInvalidToken': 'Session expired.',
    'errorSessionClosed': 'You left this game and cannot rejoin it.',
    'errorAlreadyInRoom': 'You are already in a room.',
    'errorNotPlayingPhase': 'The play phase has not started.',
    'errorNotBiddingPhase': 'Bidding is over.',
    'errorCardNotInHand': 'That card is not in your hand.',
    'errorUnknown': 'Something went wrong.',
    'rulesTitle': 'Essential rules',
    'rulesBody': '32 cards, 4 players, 2 teams.\n\n'
        'Bids from 90 to 180 in steps of 10, or capot. '
        'Capot beats every bid and cannot be doubled. '
        'Three passes after the last bid close the auction.\n\n'
        'The player to the dealer’s right speaks and leads. '
        'Follow the led suit. '
        'When trump is led you must overtake if possible, even over partner. '
        'When a plain suit is led, cut or overtrump according to the rules. '
        'A player blocked at trump must play a trump.\n\n'
        'Belote-rebelote: 20 points, declared once when playing the trump king or queen. '
        'Rebelote then completes automatically. '
        'Last trick: 10 points.\n\n'
        'The contract is made when the attack’s rounded points reach the bid. '
        'Failed contract: 160 to the defense. '
        'Doubled: 320, redoubled: 640. '
        'Called capot: 500. Uncalled capot: 250.\n\n'
        'The deal stops as soon as the contract becomes mathematically impossible.',
    'bestOf3': 'Best of 3 sets',
    'bestOf5': 'Best of 5 sets',
    'singleSet': 'Single set to 3000',
    'format': 'Format',
    'suitSpades': 'Spades',
    'suitHearts': 'Hearts',
    'suitDiamonds': 'Diamonds',
    'suitClubs': 'Clubs',
    'teamUs': 'Us',
    'teamThem': 'Them',
    'noContract': 'No contract',
    'pointsAbbr': 'pts',
    'cards': 'cards',
    'tricks': 'tricks',
    'lastTrick': 'Last trick',
    'log': 'Log',
    'waitingHost': 'Waiting for the host to start…',
    'roomCreated': 'Room created',
    'joinHint': 'Enter the 5-character code shared by the host.',
    'nameHint': 'Your first name',
    'serverHint': 'ws://192.168.1.10:8080/ws',
    'autoPlay': 'Played automatically',
    'turnTimeout': 'Time is up: automatic move.',
    'contractBy': '{name}’s contract',
    'attack': 'Attack',
    'defense': 'Defense',
    'setScores': 'Set score',
    'matchScores': 'Sets won',
    'dealNumber': 'Deal {number}',
    'dealerShort': 'D',
    'waitingConnection': 'Connecting to server…',
    'connecting': 'Connecting…',
    'spectator': 'Spectator',
    'earlyStoppedShort': 'Early stop',
    'eventDealStarted': 'Deal dealt by {dealer}',
    'eventRedealAllPass': 'Four passes: new deal',
    'eventRedealSuit': '7 or 8 cards in one suit: redeal',
    'eventPass': '{seat} passes',
    'eventBid': '{seat} bids {amount} {suit}',
    'eventCapot': '{seat} calls capot in {suit}',
    'eventCounter': '{seat} doubles',
    'eventSurcounter': '{seat} redoubles',
    'eventContract': 'Contract: {amount} {suit} by {seat}',
    'eventPlay': '{seat} plays {card}',
    'eventTrick': '{seat} wins the trick ({points} pts)',
    'eventBelote': '{seat} declares Belote',
    'eventRebelote': '{seat} declares Rebelote',
    'eventEarlyStopContract': 'Contract became impossible: stopped',
    'eventEarlyStopCapot': 'Capot failed: stopped',
    'eventDealEnd': 'End of deal',
    'eventSetEnd': 'Set won by {team}',
    'eventMatchEnd': 'Match won by {team}',
    'eventSetTie': 'Tie at target: new deal',
    'gameCode': 'Code',
    'leaveConfirmTitle': 'Leave the game?',
    'leaveConfirmBody':
        'A bot will take over your seat. You cannot rejoin this game.',
    'confirmLeave': 'Leave',
    'stay': 'Stay',
    'notYourTurn': 'Please wait…',
    'tapCardToPlay': 'Tap a highlighted card',
    'bidHint': 'Choose an amount and a trump',
    'capotHint': 'Top bid: all eight tricks required',
    'chatEmpty': 'No messages yet.',
    'chatSendError': 'Could not send the message.',
    'serverTime': 'Server',
    'version': 'Version 0.1',
    'pointsWon': '{points} pts',
    'tricksWon': '{count} tricks',
    'outOfTurnAction': 'Out-of-turn action available',
    'counterAvailable': 'You can double',
    'surcounterAvailable': 'You can redouble',
    'waitingForHost': 'Waiting for the host',
    'readyToStart': 'All players are ready',
    'seatNumber': 'Seat {number}',
    'host': 'Host',
    'disconnected': 'Disconnected',
    'autoControlled': 'Temporary bot',
    'formatHint': 'Choose the game format',
    'saveSettings': 'Save settings',
    'settingsSaved': 'Settings saved',
    'languageFrench': 'Français',
    'languageEnglish': 'English',
    'resumeHint': 'A recent session is available.',
    'amount': 'Amount',
    'suit': 'Suit',
    'seeTable': 'View table',
    'newDealSoon': 'New deal in a moment…',
    'waitingPlayersCount': '{count}/4 players',
    'noBidsYet': 'No bids yet',
    'matchEndTitle': 'End of match',
    'waitingTurn': '{name}’s turn',
    'beloteHint': 'Play the trump king or queen to declare belote (once only).',
    'clearSession': 'Forget session',
    'menu': 'Menu',
    'setsWonShort': '{count} set(s)',
    'yourTurn': 'Your turn',
    'roomInfo': 'Room {code}',
    'copyCode': 'Copy code',
    'shareCode': 'Share this code with your friends.',
    'leaveLobbyBody': 'You will leave the room and free your seat.',
    'capotOnly': 'Capot only',
  };
}

class L10nDelegate extends LocalizationsDelegate<L10n> {
  const L10nDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'fr' || locale.languageCode == 'en';

  @override
  Future<L10n> load(Locale locale) => SynchronousFuture(L10n(locale));

  @override
  bool shouldReload(L10nDelegate old) => false;
}
