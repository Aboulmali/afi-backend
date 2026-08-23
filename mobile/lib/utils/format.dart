const _mois = ['Janv', 'Févr', 'Mars', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sept', 'Oct', 'Nov', 'Déc'];
const _moisLong = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
const _jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

String formatMontant(int v) {
  final sign = v < 0 ? '−' : '';
  final s = v.abs().toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '$sign$b';
}

String formatF(int v) => '${formatMontant(v)} F';
String formatFCFA(int v) => '${formatMontant(v)} F CFA';

String formatDateListe(DateTime d) => '${d.day} ${_mois[d.month - 1]} ${d.year}';
String formatDateDetail(DateTime d) =>
    '${d.day} ${_mois[d.month - 1]} ${d.year}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String formatDateHome(DateTime d, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return "Aujourd'hui, ${hhmm(d)}";
  if (diff == 1) return 'Hier, ${hhmm(d)}';
  return '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]}, ${hhmm(d)}';
}

String hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String moisAnnee(DateTime d) => '${_moisLong[d.month - 1]} ${d.year}';

String montantSigne(int v) {
  final s = formatMontant(v.abs());
  return v < 0 ? '−$s F' : '+$s F';
}

String montantSigneCFA(int v) {
  final s = formatMontant(v.abs());
  return v < 0 ? '−$s F' : '+$s F';
}

String dateAujourdhui() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
