import 'package:tulgusch/core/api/schedule_api.dart';

/// Итоговая оценка за семестр. Баллы за пары в API не приходят —
/// это отдельный, локальный слой журнала.
class MarksItem {
  final String term;
  final String discipline;
  final String mark;
  final String markTitle;
  final String teacherMark;
  final String retake;
  final bool recredit;

  const MarksItem({
    required this.term,
    required this.discipline,
    required this.mark,
    required this.markTitle,
    required this.teacherMark,
    required this.retake,
    required this.recredit,
  });

  int get termNumber => int.tryParse(term) ?? 0;

  bool get isAttested => markTitle.isNotEmpty;

  /// Ключи нейтральные; старые снимки писали их в верхнем регистре,
  /// поэтому чтение терпит оба варианта.
  Map<String, dynamic> toJson() => {
        'term': term,
        'discipline': discipline,
        'mark': mark,
        'markTitle': markTitle,
        'teacherMark': teacherMark,
        'retake': retake,
        'recredit': recredit,
      };

  factory MarksItem.fromJson(Map<String, dynamic> json) {
    String read(String key) => '${json[key] ?? json[key.toUpperCase()] ?? ''}';
    final rawRecredit = json['recredit'] ?? json['RECREDIT'];
    return MarksItem(
      term: read('term'),
      discipline: read('discipline'),
      mark: read('mark'),
      markTitle: read('markTitle'),
      teacherMark: read('teacherMark'),
      retake: read('retake'),
      recredit: rawRecredit == true || rawRecredit == '1',
    );
  }

  factory MarksItem.fromFinalMark(FinalMark mark) => MarksItem(
        term: mark.term,
        discipline: mark.discipline,
        mark: '',
        markTitle: mark.markTitle,
        teacherMark: mark.teacherMark,
        retake: mark.retake,
        recredit: mark.recredit,
      );
}
