import 'card.dart';
import 'contract.dart';

/// Suivi de la belote-rebelote d'une donne.
///
/// La belote se déclare **une seule fois**, en jouant le roi ou la dame
/// d'atout tant qu'aucune autre carte n'a été jouée par ce joueur. Une fois
/// déclarée, la seconde carte d'atout valide automatiquement la rebelote.
class BeloteTracker {
  BeloteTracker({required this.trump, required Map<int, List<Card>> hands}) {
    for (final entry in hands.entries) {
      final hasKing = entry.value.any(
        (card) => card.suit == trump && card.rank == Rank.king,
      );
      final hasQueen = entry.value.any(
        (card) => card.suit == trump && card.rank == Rank.queen,
      );
      holds[entry.key] = hasKing && hasQueen;
      _played[entry.key] = <Card>{};
    }
  }

  final Suit trump;
  final Map<int, bool> holds = {};
  final Map<int, bool> declaredFirst = {};
  final Map<int, bool> declined = {};
  final Map<int, bool> completed = {};
  final Map<int, bool> rebeloteDeclared = {};
  final Map<int, Set<Card>> _played = {};

  bool holderHolds(int seat) => holds[seat] == true;

  /// Équipe ayant déclaré et validé la belote, ou `null`.
  int? get completedTeam {
    for (final entry in completed.entries) {
      if (entry.value) return teamOf(entry.key);
    }
    return null;
  }

  int? get holderSeat {
    for (final entry in holds.entries) {
      if (entry.value) return entry.key;
    }
    return null;
  }

  bool get bonusSecured => completedTeam != null;

  /// `true` si les 20 points peuvent encore être obtenus par [team].
  bool canStillEarn(int team) {
    for (final entry in holds.entries) {
      if (!entry.value || teamOf(entry.key) != team) continue;
      if (completed[entry.key] == true) return false; // déjà acquis
      if (declined[entry.key] == true) return false;
      final played = _played[entry.key] ?? const {};
      if (played.isEmpty) return true;
      if (played.length == 1) {
        return declaredFirst[entry.key] == true;
      }
      return false;
    }
    return false;
  }

  /// Vrai si la belote de cette équipe est déjà validée ou encore possible.
  bool canStillEarnOrSecured(int team) =>
      completedTeam == team || canStillEarn(team);

  bool isBeloteCard(int seat, Card card) =>
      holds[seat] == true &&
      card.suit == trump &&
      (card.rank == Rank.king || card.rank == Rank.queen);

  /// La déclaration n'est possible que sur la toute première carte du joueur.
  bool canDeclareFirst(int seat, Card card) {
    if (!isBeloteCard(seat, card)) return false;
    if (completed[seat] == true || declined[seat] == true) return false;
    if (declaredFirst[seat] == true) return false;
    return (_played[seat] ?? const {}).isEmpty;
  }

  bool canStillDeclareFirst(int seat) {
    if (holds[seat] != true) return false;
    if (declaredFirst[seat] == true || completed[seat] == true) return false;
    if (declined[seat] == true) return false;
    return (_played[seat] ?? const {}).isEmpty;
  }

  /// Vrai si cette carte valide automatiquement la rebelote déjà déclarée.
  bool canDeclareRebelote(int seat, Card card) {
    if (!isBeloteCard(seat, card)) return false;
    if (declaredFirst[seat] != true) return false;
    if (completed[seat] == true) return false;
    return (_played[seat] ?? const {}).length == 1;
  }

  /// Met à jour l'état quand [seat] joue [card].
  ///
  /// [declareBelote] n'est lu que sur la première carte : la rebelote, elle,
  /// se valide seule dès que la seconde carte d'atout tombe.
  void onCardPlayed(int seat, Card card, {required bool declareBelote}) {
    if (isBeloteCard(seat, card)) {
      final played = _played[seat] ?? <Card>{};
      final otherRank = card.rank == Rank.king ? Rank.queen : Rank.king;
      final otherPlayed = played.any(
        (playedCard) =>
            playedCard.suit == trump && playedCard.rank == otherRank,
      );

      if (!otherPlayed) {
        if (declareBelote) {
          declaredFirst[seat] = true;
        } else {
          declined[seat] = true;
        }
      } else if (declaredFirst[seat] == true) {
        rebeloteDeclared[seat] = true;
        completed[seat] = true;
      }
      played.add(card);
      _played[seat] = played;
    }
  }

  Map<String, dynamic> toJson() => {
        'trump': trump.code,
        'holds': {for (final e in holds.entries) '${e.key}': e.value},
        'declaredFirst': {
          for (final e in declaredFirst.entries) '${e.key}': e.value,
        },
        'declined': {for (final e in declined.entries) '${e.key}': e.value},
        'completed': {
          for (final e in completed.entries) '${e.key}': e.value,
        },
        'holderSeat': holderSeat,
        'completedTeam': completedTeam,
      };
}
