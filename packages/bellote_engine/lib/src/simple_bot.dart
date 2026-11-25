import 'dart:math';

import 'auction.dart';
import 'card.dart';
import 'contract.dart';
import 'game.dart';
import 'rules.dart';
import 'view.dart';

class PlayDecision {
  const PlayDecision({required this.card, this.declareBelote = false});

  final Card card;
  final bool declareBelote;
}

/// IA simple, déterministe à graine près. Elle respecte toujours les cartes
/// légales fournies par le moteur.
class SimpleBot {
  SimpleBot({Random? random}) : _random = random ?? Random();

  final Random _random;

  // ---------------------------------------------------------------------------
  // Enchères
  // ---------------------------------------------------------------------------

  BidAction decideBid(BelloteGame game, int seat) {
    final view = game.viewFor(seat);
    if (!view.isBidding || !view.isMyTurn || !view.canBidNumbers) {
      if (view.isBidding && view.isMyTurn) return const PassBid();
      return const PassBid();
    }

    final best = _bestTrump(view.hand);
    if (best == null) return const PassBid();

    BidRecord? lastBid;
    for (final record in view.auctionHistory) {
      if (record.action is NumberBid || record.action is CapotBid) {
        lastBid = record;
      }
    }
    if (lastBid == null) {
      return NumberBid(amount: 90, trump: best.suit);
    }

    final amount = switch (lastBid.action) {
      NumberBid(:final amount) => amount,
      _ => null,
    };
    if (amount == null) return const PassBid();

    if (teamOf(lastBid.seat) == view.myTeam) return const PassBid();
    if (amount >= 130) return const PassBid();
    if (amount <= 100 && best.score >= 95) {
      return NumberBid(amount: amount + 10, trump: best.suit);
    }
    return const PassBid();
  }

  _TrumpChoice? _bestTrump(List<Card> hand) {
    _TrumpChoice? best;
    for (final suit in Suit.values) {
      final trumps = hand.where((card) => card.suit == suit).toList();
      if (trumps.isEmpty) continue;
      var score = 0;
      for (final card in hand) {
        score += card.points(suit);
      }
      score += trumps.length * 7;
      if (trumps.any((card) => card.rank == Rank.jack)) score += 12;
      if (trumps.any((card) => card.rank == Rank.nine)) score += 6;
      if (best == null || score > best.score) {
        best = _TrumpChoice(suit, score);
      }
    }
    return best;
  }

  // ---------------------------------------------------------------------------
  // Jeu des cartes
  // ---------------------------------------------------------------------------

  PlayDecision? decidePlay(BelloteGame game, int seat) {
    final view = game.viewFor(seat);
    if (!view.isPlaying || !view.isMyTurn || view.legalCards.isEmpty) {
      return null;
    }

    final trump = view.trump;
    if (trump == null) return null;

    final legal = [...view.legalCards];
    final card = _chooseCard(view, trump, legal);

    // Un bot annonce la belote en jouant la première de ses deux cartes
    // d'atout. La rebelote se valide ensuite automatiquement.
    final declareBelote = view.canDeclareBelote &&
        card.suit == trump &&
        (card.rank == Rank.king || card.rank == Rank.queen);

    return PlayDecision(card: card, declareBelote: declareBelote);
  }

  Card _chooseCard(PlayerView view, Suit trump, List<Card> legal) {
    final trick = view.currentTrick;

    if (trick.isEmpty) {
      return _chooseLead(view, trump, legal);
    }

    final master = trickMaster(trick, trump);
    final partnerMaster = master != null && sameTeam(master.seat, view.seat);
    final isLast = trick.length == 3;
    final winners = legal
        .where((card) =>
            TrickRules.wouldWin(card: card, trick: trick, trump: trump))
        .toList();

    if (partnerMaster) {
      if (isLast) {
        // Partenaire maître et dernier à parler : engranger les points.
        return _highestValue(legal, trump);
      }
      return _lowestValue(legal, trump);
    }

    if (winners.isNotEmpty) {
      // Gagner au moindre coût.
      winners.sort((a, b) {
        final strength = a.strength(trump).compareTo(b.strength(trump));
        if (strength != 0) return strength;
        return a.points(trump).compareTo(b.points(trump));
      });
      return winners.first;
    }

    return _lowestValue(legal, trump);
  }

  Card _chooseLead(PlayerView view, Suit trump, List<Card> legal) {
    final trumps = legal.where((card) => card.suit == trump).toList();
    final plain = legal.where((card) => card.suit != trump).toList();

    // Tôt dans la donne, tirer les atouts avec une force suffisante.
    if (trumps.length >= 2 && view.tricksPlayed < 5) {
      final honors = trumps
          .where((card) =>
              card.rank == Rank.jack ||
              card.rank == Rank.nine ||
              card.rank == Rank.ace)
          .toList();
      if (honors.isNotEmpty && _random.nextDouble() < 0.65) {
        honors.sort(
          (a, b) => b.strength(trump).compareTo(a.strength(trump)),
        );
        return honors.first;
      }
    }

    // Sinon, dégager un As hors atout.
    final aces = plain.where((card) => card.rank == Rank.ace).toList();
    if (aces.isNotEmpty) return aces.first;

    final pool = plain.isNotEmpty ? plain : legal;
    return _lowestValue(pool, trump);
  }

  Card _lowestValue(List<Card> cards, Suit trump) {
    final sorted = [...cards]..sort((a, b) {
        final points = a.points(trump).compareTo(b.points(trump));
        if (points != 0) return points;
        return a.strength(trump).compareTo(b.strength(trump));
      });
    // Un peu d'aléatoire entre cartes de même valeur.
    final minPoints = sorted.first.points(trump);
    final cheapest =
        sorted.where((card) => card.points(trump) == minPoints).toList();
    return cheapest[_random.nextInt(cheapest.length)];
  }

  Card _highestValue(List<Card> cards, Suit trump) {
    final sorted = [...cards]..sort((a, b) {
        final points = b.points(trump).compareTo(a.points(trump));
        if (points != 0) return points;
        return b.strength(trump).compareTo(a.strength(trump));
      });
    return sorted.first;
  }
}

class _TrumpChoice {
  const _TrumpChoice(this.suit, this.score);

  final Suit suit;
  final int score;
}
