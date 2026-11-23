import 'card.dart';
import 'contract.dart';

class PlayedCard {
  const PlayedCard({required this.seat, required this.card});

  final int seat;
  final Card card;

  Map<String, dynamic> toJson() => {'seat': seat, 'card': card.id};

  static PlayedCard fromJson(Map<String, dynamic> json) => PlayedCard(
        seat: json['seat'] as int,
        card: Card.parse(json['card'] as String),
      );
}

class TrickRecord {
  const TrickRecord({
    required this.leaderSeat,
    required this.plays,
    required this.winnerSeat,
    required this.points,
    required this.winningTeam,
  });

  final int leaderSeat;
  final List<PlayedCard> plays;
  final int winnerSeat;
  final int points;
  final int winningTeam;

  Map<String, dynamic> toJson() => {
        'leaderSeat': leaderSeat,
        'plays': [for (final play in plays) play.toJson()],
        'winnerSeat': winnerSeat,
        'points': points,
        'winningTeam': winningTeam,
      };

  static TrickRecord fromJson(Map<String, dynamic> json) => TrickRecord(
        leaderSeat: json['leaderSeat'] as int,
        plays: [
          for (final play in json['plays'] as List)
            PlayedCard.fromJson(play as Map<String, dynamic>),
        ],
        winnerSeat: json['winnerSeat'] as int,
        points: json['points'] as int,
        winningTeam: json['winningTeam'] as int,
      );
}

/// Maître actuel d'un pli en cours.
PlayedCard? trickMaster(List<PlayedCard> plays, Suit trump) {
  if (plays.isEmpty) return null;

  final trumps = plays.where((play) => play.card.suit == trump).toList();
  if (trumps.isNotEmpty) {
    var best = trumps.first;
    for (final play in trumps.skip(1)) {
      if (play.card.strength(trump) > best.card.strength(trump)) best = play;
    }
    return best;
  }

  final ledSuit = plays.first.card.suit;
  var best = plays.first;
  for (final play in plays.skip(1)) {
    if (play.card.suit != ledSuit) continue;
    if (play.card.strength(trump) > best.card.strength(trump)) best = play;
  }
  return best;
}

int trickWinnerSeat(List<PlayedCard> plays, Suit trump) {
  final master = trickMaster(plays, trump);
  if (master == null) {
    throw ArgumentError('Un pli vide n\'a pas de gagnant');
  }
  return master.seat;
}

int trickCardPoints(List<PlayedCard> plays, Suit trump) =>
    plays.fold(0, (sum, play) => sum + play.card.points(trump));

/// Règles de jeu des cartes.
abstract final class TrickRules {
  /// Cartes légales pour [seat] sur le pli courant.
  ///
  /// [hand] est la main du joueur avant de jouer.
  static Set<Card> legalCards({
    required int seat,
    required List<Card> hand,
    required List<PlayedCard> trick,
    required Suit trump,
  }) {
    if (hand.isEmpty) return const {};

    // Le joueur entame : toute carte est permise.
    if (trick.isEmpty) return hand.toSet();

    final ledSuit = trick.first.card.suit;

    // Cas 1 : la couleur demandée est l'atout.
    if (ledSuit == trump) {
      final trumpsInTrick =
          trick.where((play) => play.card.suit == trump).toList();
      double? bestTrump;
      if (trumpsInTrick.isNotEmpty) {
        bestTrump = trumpsInTrick
            .map((play) => play.card.strength(trump).toDouble())
            .reduce((a, b) => a > b ? a : b);
      }

      final myTrumps = hand.where((card) => card.suit == trump).toList();
      if (myTrumps.isEmpty) return hand.toSet(); // défausse libre

      if (bestTrump != null) {
        final higher = myTrumps
            .where((card) => card.strength(trump) > bestTrump!)
            .toList();
        if (higher.isNotEmpty) return higher.toSet();
      }
      // Pisser : n'importe quel atout.
      return myTrumps.toSet();
    }

    // Cas 2 : la couleur demandée est hors atout.
    final myLedSuit = hand.where((card) => card.suit == ledSuit).toList();
    if (myLedSuit.isNotEmpty) {
      // Fournir la couleur demandée, sans obligation de monter.
      return myLedSuit.toSet();
    }

    final myTrumps = hand.where((card) => card.suit == trump).toList();
    final blockedAtTrump =
        hand.every((card) => card.suit == trump); // toutes les cartes restantes

    final master = trickMaster(trick, trump);
    final partnerIsMaster = master != null && sameTeam(master.seat, seat);

    double? bestTrump;
    for (final play in trick) {
      if (play.card.suit != trump) continue;
      final strength = play.card.strength(trump).toDouble();
      if (bestTrump == null || strength > bestTrump) bestTrump = strength;
    }

    if (partnerIsMaster) {
      if (blockedAtTrump) {
        // Bloqué à l'atout : ne peut pas défausser.
        if (bestTrump == null) return myTrumps.toSet(); // doit couper
        final higher = myTrumps
            .where((card) => card.strength(trump) > bestTrump!)
            .toList();
        if (higher.isNotEmpty) return higher.toSet(); // surcoupe obligatoire
        return myTrumps.toSet(); // pisse obligatoire
      }
      // Partenaire maître et joueur non bloqué : défausse ou atout libre.
      return hand.toSet();
    }

    // Partenaire n'est pas maître.
    if (myTrumps.isEmpty) return hand.toSet(); // défausse libre

    if (bestTrump == null) {
      // Personne n'a encore coupé : obligation de couper.
      return myTrumps.toSet();
    }

    final higher =
        myTrumps.where((card) => card.strength(trump) > bestTrump!).toList();
    if (higher.isNotEmpty) return higher.toSet(); // surcoupe obligatoire
    return myTrumps.toSet(); // pisse obligatoire
  }

  /// Indique si [card] battrait le pli courant s'il était joué maintenant.
  static bool wouldWin({
    required Card card,
    required List<PlayedCard> trick,
    required Suit trump,
  }) {
    final simulated = [
      ...trick,
      PlayedCard(seat: 99, card: card),
    ];
    return trickWinnerSeat(simulated, trump) == 99;
  }
}
