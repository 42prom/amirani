import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amirani_app/theme/app_theme.dart';
import '../../../../core/data/exercise_database.dart';
import '../../domain/entities/workout_preferences_entity.dart';
import '../../domain/entities/monthly_workout_plan_entity.dart';

// ─── State ────────────────────────────────────────────────────────────────────
class MuscleSelectionState {
  final Set<MuscleGroup> selectedMuscles;
  final List<ExerciseData> availableExercises;
  const MuscleSelectionState(
      {this.selectedMuscles = const {}, this.availableExercises = const []});
  MuscleSelectionState copyWith(
          {Set<MuscleGroup>? selectedMuscles,
          List<ExerciseData>? availableExercises}) =>
      MuscleSelectionState(
          selectedMuscles: selectedMuscles ?? this.selectedMuscles,
          availableExercises: availableExercises ?? this.availableExercises);
}

class MuscleSelectionNotifier extends StateNotifier<MuscleSelectionState> {
  MuscleSelectionNotifier() : super(const MuscleSelectionState());
  void toggleMuscle(MuscleGroup m) {
    final s = Set<MuscleGroup>.from(state.selectedMuscles);
    s.contains(m) ? s.remove(m) : s.add(m);
    state = state.copyWith(selectedMuscles: s);
    _update();
  }

  void deselectMuscle(MuscleGroup m) {
    final s = Set<MuscleGroup>.from(state.selectedMuscles)..remove(m);
    state = state.copyWith(selectedMuscles: s);
    _update();
  }

  void clearSelection() =>
      state = state.copyWith(selectedMuscles: {}, availableExercises: []);
      
  void setMuscles(Set<MuscleGroup> muscles) {
    state = state.copyWith(selectedMuscles: muscles);
    _update();
  }
  void _update() {
    if (state.selectedMuscles.isEmpty) {
      state = state.copyWith(availableExercises: []);
      return;
    }
    state = state.copyWith(
        availableExercises: ExerciseDatabase.instance.getExercisesWithEquipment(
            state.selectedMuscles.toList(), Equipment.values.toList()));
  }
}

final muscleSelectionProvider =
    StateNotifierProvider<MuscleSelectionNotifier, MuscleSelectionState>(
        (ref) => MuscleSelectionNotifier());

// ─── Canvas bounds per view ───────────────────────────────────────────────────
class _CanvasBounds {
  final double xMin, yMin, xMax, yMax;
  const _CanvasBounds(this.xMin, this.yMin, this.xMax, this.yMax);
  double get width => xMax - xMin;
  double get height => yMax - yMin;
}

// All bounds: width=400, height=850 — matching the PNG and SVG canvas.
// SAME formula as confirmed-perfect maleFront:
//   xMin = body_center_x - 195   (195 = 542-347, same offset as front)
//   yMax = bottommost_Y + 81     (81  = 482-401, same bottom margin as front)
//   yMin = yMax - 850
// maleFront: center=542, bottom=401 → (347,-368,747,482) ← confirmed perfect
// maleBack:  center=436, bottom=718 → xMin=241, yMax=799, yMin=-51
// femaleFront: center=438, bottom=776 → xMin=243, yMax=857, yMin=7
// femaleBack:  center=150, bottom=826 → xMin=-45, yMax=907, yMin=57
const _maleFrontBounds =
    _CanvasBounds(347, -368, 747, 482); // 400×850 ← perfect
const _maleBackBounds =
    _CanvasBounds(235, -67, 635, 783); // 400×850  right+8, up+6
const _femaleFrontBounds =
    _CanvasBounds(237, 13, 637, 863); // 400×850 ← perfect
const _femaleBackBounds = _CanvasBounds(-51, 42, 349, 892); // 400×850  right+1

// ─── SVG Sector ───────────────────────────────────────────────────────────────
class _SvgSector {
  final MuscleGroup muscle;
  final bool isFront;
  final String d; // raw SVG path data (M/L/C/Z, absolute coords)
  const _SvgSector(this.muscle, this.isFront, this.d);
}

// ─── SVG path parser (handles M, L, C, Z absolute commands) ──────────────────
Path _parseSvgPath(String d, _CanvasBounds bounds, double w, double h) {
  double tx(double x) => (x - bounds.xMin) / bounds.width * w;
  double ty(double y) => (y - bounds.yMin) / bounds.height * h;

  final path = Path();
  final re = RegExp(r'([MLCZmlcz])([^MLCZmlcz]*)');
  for (final m in re.allMatches(d)) {
    final cmd = m.group(1)!;
    final args = m.group(2)!.trim();
    final nums = args.isEmpty
        ? <double>[]
        : args
            .split(RegExp(r'[\s,]+'))
            .where((s) => s.isNotEmpty)
            .map(double.parse)
            .toList();
    switch (cmd) {
      case 'M':
        if (nums.length >= 2) {
          path.moveTo(tx(nums[0]), ty(nums[1]));
          for (int i = 2; i + 1 < nums.length; i += 2) {
            path.lineTo(tx(nums[i]), ty(nums[i + 1]));
          }
        }
      case 'L':
        for (int i = 0; i + 1 < nums.length; i += 2) {
          path.lineTo(tx(nums[i]), ty(nums[i + 1]));
        }
      case 'C':
        for (int i = 0; i + 5 < nums.length; i += 6) {
          path.cubicTo(
            tx(nums[i]),
            ty(nums[i + 1]),
            tx(nums[i + 2]),
            ty(nums[i + 3]),
            tx(nums[i + 4]),
            ty(nums[i + 5]),
          );
        }
      case 'Z':
      case 'z':
        path.close();
    }
  }
  return path..close();
}

// ─── Male Front paths (17 shapes) ────────────────────────────────────────────
const _maleFront = <_SvgSector>[
  _SvgSector(MuscleGroup.chest, true,
      'M592,-212L606,-202L616,-192L624,-177L627,-171L625,-158L612,-135L597,-125L581,-123L561,-131L548,-139L545,-161L548,-186L555,-204L563,-210L592,-212'),
  _SvgSector(MuscleGroup.chest, true,
      'M488,-213L504,-212L522,-209L530,-202L537,-180L539,-162L538,-146L535,-136L520,-130L506,-125L495,-123L483,-127L474,-132L465,-144L461,-156L457,-163L455,-167L463,-184L476,-199L488,-213'),
  _SvgSector(MuscleGroup.shoulders, true,
      'M592,-212L602,-218L616,-220L630,-217L643,-207C643,-207,649,-201,650,-200C651,-199,656,-189,656,-189L661,-178L662,-161L661,-151L659,-139L647,-152L634,-160L627,-165L625,-174L616,-191L602,-203L592,-212'),
  _SvgSector(MuscleGroup.shoulders, true,
      'M489,-213L480,-204L472,-194L462,-182L456,-170L454,-164L443,-157L433,-147L426,-136L422,-148L422,-174L429,-193L437,-205L450,-216L464,-220L478,-219L489,-213'),
  _SvgSector(MuscleGroup.abs, true,
      'M535,-134L522,-129L512,-125L506,-123L503,-113L503,-100L503,-76L504,-51L507,-23L511,-7L517,9L523,26L530,36L537,42L547,42L558,30L565,16L572,-7L576,-20L579,-51L580,-80L581,-110L578,-121L569,-125L560,-129L552,-131L535,-134'),
  _SvgSector(MuscleGroup.calves, true,
      'M616,250L614,267L616,284L615,309L607,342L599,373L594,394L605,400L610,380L617,353L624,316L627,296L623,271L616,250'),
  _SvgSector(MuscleGroup.calves, true,
      'M570,264L566,290L564,307L566,324L573,347L577,365L580,388L581,397L586,369L586,335L586,297L578,277L570,264'),
  _SvgSector(MuscleGroup.calves, true,
      'M515,262L506,277L500,294L499,312L499,336L499,350L500,375L500,383L504,397L509,360L515,335L521,311L521,292L518,277L515,262'),
  _SvgSector(MuscleGroup.calves, true,
      'M466,247L462,275L459,290L458,305L462,328L469,356L474,381L476,401L490,395L486,371L477,338L471,309L469,287L471,267L466,247'),
  _SvgSector(MuscleGroup.quads, true,
      'M601,-2L586,17L573,39L560,66L551,78L551,106L553,130L560,151L560,185L562,205L569,222L577,224L583,214L586,201L586,192L598,192L598,206L601,218L608,228L615,200L625,168L629,145L629,116L628,96L619,70L609,49L603,32L601,17L601,-2'),
  _SvgSector(MuscleGroup.quads, true,
      'M480,-2L484,14L482,34L476,54L460,79L455,104L455,142L462,175L467,191L478,209L486,205L487,198L497,195L500,210L505,223L517,218L523,201L523,169L531,130L533,102L533,75L523,61L510,35L498,16L480,-2'),
  _SvgSector(MuscleGroup.obliques, true,
      'M592,-122L586,-113L584,-93L585,-66L585,-47L584,-29L582,-13L581,-2L596,-3L612,-18L612,-38L609,-52L609,-73L612,-85L616,-92L610,-97L613,-106L606,-110L609,-118L602,-124L592,-122'),
  _SvgSector(MuscleGroup.obliques, true,
      'M495,-118L487,-123L475,-121L480,-113L479,-109L472,-109L475,-99L469,-95L471,-82L474,-75L475,-61L474,-50L471,-37L471,-27L473,-14L480,-8L492,-3L502,-3L500,-24L498,-37L498,-53L499,-65L500,-87L498,-98L497,-104L498,-112L495,-118'),
  _SvgSector(MuscleGroup.biceps, true,
      'M656,-143L644,-154L629,-164L623,-143L624,-121L630,-103L635,-88L642,-72L656,-63L651,-81L662,-85L668,-77L675,-94L673,-119L668,-139L662,-151L656,-143'),
  _SvgSector(MuscleGroup.biceps, true,
      'M454,-162L459,-154L461,-141L459,-126L456,-111L450,-90L445,-79L441,-72L422,-57L433,-77L430,-81L424,-83L419,-81L416,-84L411,-91L408,-96L412,-125L418,-143L421,-149L425,-139L433,-145L439,-151L446,-157L454,-162'),
  _SvgSector(MuscleGroup.forearms, true,
      'M674,-94L667,-81L667,-56L654,-64L642,-71L645,-42L652,-19L665,4L678,33L704,30L697,-11L692,-54L684,-77L674,-94'),
  _SvgSector(MuscleGroup.forearms, true,
      'M409,-93L415,-85L417,-74L419,-56L418,-49L428,-58L438,-67L442,-70L440,-49L436,-32L428,-12L413,21L407,37L383,30L386,14L389,-26L390,-47L396,-66L403,-83L409,-93'),
];

// ─── Male Back paths (13 shapes) ─────────────────────────────────────────────

const _maleBack = <_SvgSector>[
  _SvgSector(MuscleGroup.back, false,
      'M489,104L496,109L506,117L512,123L518,127L522,133L517,145L515,156L514,167L514,179L514,189L509,204L504,219L500,232L498,240L491,255L483,268L481,281L470,282L457,287L451,294L445,303L439,314L436,323L431,312L425,301L417,292L408,285L399,281L390,281L386,267L381,258L376,248L372,237L369,226L365,214L361,200L358,188L358,171L356,157L354,145L352,135L354,128L363,121L372,112L378,106L383,102L387,111L391,120L396,130L399,139L403,150L407,162L412,173L417,182L424,193L428,202L432,209L439,209L443,199L450,187L454,177L460,168L466,157L470,144L474,132L478,120L484,111L489,104'),
  _SvgSector(MuscleGroup.glutes, false,
      'M435,328L429,314L422,303L412,291L401,285L387,285L377,289L372,299L369,312L367,327L366,338L365,350L365,363L367,372L373,382L383,389L396,392L411,390L423,383L433,373L439,373L444,380L451,386L461,391L473,393L486,390L496,382L503,372L506,357L505,340L503,324L501,308L498,296L490,286L476,284L465,288L453,299L445,311L435,328'),
  _SvgSector(MuscleGroup.shoulders, false,
      'M522,81L512,88L500,93L491,97L488,103L498,111L508,120L519,129L530,137L541,146L551,156L556,160L556,144L557,125L553,108L547,96L536,87L522,81'),
  _SvgSector(MuscleGroup.shoulders, false,
      'M382,103L366,117L352,130L339,139L323,151L318,157L315,144L313,129L316,113L323,98L331,88L347,81L360,87L374,94L382,103'),
  _SvgSector(MuscleGroup.traps, false,
      'M421,28L415,42L409,51L394,61L371,72L356,79L350,81L368,88L379,93L385,98L383,104L395,129L404,154L410,170L421,190L432,211L439,211L457,175L467,155L475,132L481,116L489,103L485,98L497,91L513,84L519,81L492,69L476,60L463,51L455,41L450,28L436,32L421,28'),
  _SvgSector(MuscleGroup.hamstrings, false,
      'M468,396L463,407L461,421L458,438L456,456L455,470L453,483L454,498L457,512L458,529L460,542L462,557L469,545L478,532L485,518L488,509L491,520L495,529L502,540L502,521L502,503L504,483L506,463L506,446L505,428L502,412L495,401L482,396L468,396'),
  _SvgSector(MuscleGroup.hamstrings, false,
      'M398,394L381,396L371,405L367,417L365,435L364,451L365,469L368,498L368,517L368,542L377,525L383,514L390,529L398,539L407,556L411,544L413,525L414,506L418,490L416,476L414,458L412,434L410,416L406,400L398,394'),
  _SvgSector(MuscleGroup.calves, false,
      'M475,537L468,548L461,562L458,576L457,593L455,608L457,621L460,637L465,648L474,642L479,631L484,616L486,629L490,636L496,639L504,633L497,655L492,667L490,680L488,695L487,706L486,715L493,698L498,683L502,667L506,651L511,633L514,615L514,601L513,586L509,571L506,557L503,545L497,534L492,527L486,538L482,546L475,537'),
  _SvgSector(MuscleGroup.calves, false,
      'M387,543L382,533L378,525L372,537L367,546L366,559L363,573L360,588L357,601L358,616L360,629L362,640L365,658L368,675L373,692L380,710L385,718L384,700L381,682L377,667L374,654L371,645L368,638L376,637L381,633L385,627L387,619L391,628L393,635L396,642L400,647L405,650L410,637L414,623L416,612L415,598L413,583L410,570L407,559L402,547L395,537L387,543'),
  _SvgSector(MuscleGroup.forearms, false,
      'M557,274L551,261L545,252L537,245L529,235L529,248L531,259L534,274L539,286L544,297L550,311L556,325L560,337L563,345L577,343L588,337L584,322L582,306L582,291L582,273L579,260L575,247L565,235L562,246L561,256L557,274'),
  _SvgSector(MuscleGroup.forearms, false,
      'M305,232L308,247L311,264L312,277L318,263L326,252L337,242C337,242,346,227,345,229C344,231,341,248,341,248L340,263L333,283L326,300L316,317L310,332L306,344L293,344L283,339L286,320L288,302L289,284L291,268L293,252L296,241L305,232'),
  _SvgSector(MuscleGroup.triceps, false,
      'M521,132L535,141L544,149L555,158L560,174L562,189L563,208L556,240L556,211L552,199L544,185L538,193L536,201L537,212L542,224L543,233L542,246L525,225L519,207L514,190L513,172L516,150L521,132'),
  _SvgSector(MuscleGroup.triceps, false,
      'M317,158L311,171L308,190L308,206L315,240L316,217L316,206L322,194L327,185L333,193L334,205L331,221L327,234L329,247L346,224L353,201L358,187L358,166L354,148L351,132L340,139L328,148L317,158'),
];

// ─── Female Front paths (16 shapes) ──────────────────────────────────────────

const _femaleFront = <_SvgSector>[
  _SvgSector(MuscleGroup.shoulders, true,
      'M485,186L494,181L502,178L511,175L521,177L530,182L537,189L542,199L545,209L546,221L545,232L544,242L543,251L536,243L528,234L521,230L516,224L510,213L503,205L495,196L485,186'),
  _SvgSector(MuscleGroup.shoulders, true,
      'M392,183L383,180L374,177L368,175L357,177L347,182L340,189L334,199L330,209L329,218L329,228L330,238L333,250L340,242L347,236L354,231L358,224L365,214L370,206L375,200L384,192L392,183'),
  _SvgSector(MuscleGroup.chest, true,
      'M451,192L447,200L444,210L442,224L442,238L443,250L446,259L454,265L463,269L474,273L485,273L497,266L505,256L510,244L512,231L512,225L519,226L514,217L507,207L499,199L491,190L483,185L470,184L459,186L451,192'),
  _SvgSector(MuscleGroup.chest, true,
      'M425,190L420,187L412,186L401,184L393,183L386,189L373,200L367,210L359,223L365,229L368,235L367,243L368,251L371,259L376,266L384,272L394,275L408,273L420,268L430,258L435,241L434,225L432,211L430,199L425,190'),
  _SvgSector(MuscleGroup.abs, true,
      'M432,261L424,265L417,270L409,274L404,280L403,289L403,297L403,306L403,316L404,330L404,340L405,352L405,365L406,377L408,387L412,399L415,409L419,418L423,426L429,431L438,430L446,430L453,424L459,412L463,400L467,387L470,376L470,364L471,351L471,339L471,329L471,317L471,305L471,296L472,287L471,278L466,272L458,268L450,265L443,262L432,261'),
  _SvgSector(MuscleGroup.quads, true,
      'M499,609L502,599L505,586L509,575L513,562L515,549L518,535L520,522L521,509L521,497L521,485L519,473L516,462L512,452L508,443L503,433L500,422L497,412L497,401L500,392L503,385L494,394L488,404L483,412L475,421L468,432L462,440L457,449L451,456L446,463L446,474L446,486L447,498L448,509L449,520L450,531L452,542L454,555L455,571L455,583L457,594L463,601L469,606L475,599L477,587L476,575L484,575L492,575L490,584L492,595L495,602L499,609'),
  _SvgSector(MuscleGroup.quads, true,
      'M377,388L384,395L387,403L394,412L401,421L407,431L415,442L421,450L427,457L430,464L430,475L430,484L429,494L428,504L427,516L426,528L423,539C423,539,423,549,422,551C421,553,421,564,421,564L421,574L419,586L417,596L412,602L407,606L401,597L399,586L399,575L391,575L385,575L384,585L384,594L380,602L377,609L373,596L369,584L365,572L363,560L361,548L358,534L356,519L354,506L355,494L356,482L357,471L361,461L365,451L369,441L374,432L377,421L379,410L380,400L377,388'),
  _SvgSector(MuscleGroup.calves, true,
      'M502,632L505,640L509,647L512,655L514,664L514,674L514,685L513,696L511,708L508,721L505,732L502,743L499,754L497,764L494,774L490,769L489,761L490,753L484,771L482,761L484,749L485,740L485,731L486,721L487,710L487,699L488,688L489,676L492,666L493,655L497,645L502,632'),
  _SvgSector(MuscleGroup.calves, true,
      'M465,646L468,653L471,659L475,667L477,675L478,686L478,697L478,708L478,720L477,730L477,742L476,753L474,766L471,748L470,736L468,726L466,716L464,706L462,697L461,685L461,674L463,663L465,646'),
  _SvgSector(MuscleGroup.calves, true,
      'M410,646L407,655L404,663L401,670L399,677L398,687L398,698L398,709L397,720L398,731L398,741L399,749L400,758L402,766L404,753L405,741L407,729L409,717L411,706L414,697L414,684L414,673L413,662L410,646'),
  _SvgSector(MuscleGroup.calves, true,
      'M373,633L370,641L365,650L362,660L361,673L362,687L364,701L366,715L369,727L372,739L376,759L380,769L384,776L388,767L388,760L393,772L394,762L391,750L390,738L389,726L389,715L389,699L387,685L386,674L384,663L382,652L379,643L373,633'),
  _SvgSector(MuscleGroup.forearms, true,
      'M550,343L551,334L551,323L552,312L554,304L555,297L558,309L562,316L567,324L571,334L574,346L576,358L578,369L580,381L582,392L585,402L587,410L590,418L580,419L572,421L564,424L559,411L554,401L548,390L543,380L537,368L532,357L528,345L527,334L526,323L533,330L541,336L550,343'),
  _SvgSector(MuscleGroup.forearms, true,
      'M326,344L331,338L336,334L341,329L346,324L350,322L349,332L347,342L345,351L341,361L336,371L331,380L326,391L321,401L318,408L314,416L311,425L303,422L297,419L287,417L291,406L293,397L295,387L296,377L298,367L299,357L301,347L303,338L306,330L310,323L314,316L317,308L319,301L322,307L324,314L324,323L324,330L324,336L326,344'),
  _SvgSector(MuscleGroup.obliques, true,
      'M477,283L481,276L488,273L494,276L495,283L497,290L499,298L501,304L499,313L498,321L497,328L498,337L502,347L505,354L506,362L508,372L503,380L495,388L485,395L474,397L475,382L475,366L475,352L475,339L475,327L475,315L475,302L475,292L477,283'),
  _SvgSector(MuscleGroup.obliques, true,
      'M399,282L395,277L386,275L379,275L380,282L379,290L376,296L374,303L377,312L378,319L378,328L376,337L374,344L370,356L368,364L367,373L372,379L377,385L384,391L392,396L403,397L401,385L400,374L401,362L401,348L400,335L400,323L400,312L400,300L400,291L399,282'),
  _SvgSector(MuscleGroup.biceps, true,
      'M549,337L550,322L551,310L554,300L555,288L553,273L550,261L548,252L545,244L542,252L537,244L529,236L523,231L516,228L511,233L511,242L511,251L511,260L510,270L513,281L516,291L519,301L523,311L526,317L534,323L541,329L549,337'),
  _SvgSector(MuscleGroup.biceps, true,
      'M361,228L353,231L344,238L339,244L335,250L331,244L327,256L324,266L322,276L322,287L321,296L323,305L325,311L326,320L326,330L326,337L334,330L338,325L345,321L352,314L357,302L360,290L363,278L365,269L365,257L365,245L366,236L361,228'),
];

// ─── Female Back paths (12 shapes) ───────────────────────────────────────────

const _femaleBack = <_SvgSector>[
  _SvgSector(MuscleGroup.back, false,
      'M200,232L208,240L218,247L230,257L228,271L223,287L222,305L218,321L214,337L210,353L205,368L198,384L195,403L180,409L167,420L158,432L151,453L145,437L138,424L129,415L109,404L104,390L99,376L93,364L87,347L84,332L81,318L78,303L76,288L73,273L72,260L81,247L91,236L98,229L105,239L110,253L116,268L120,282L126,294L131,305L137,315L142,325L148,336L159,320L165,306L172,292L180,274L184,259L190,244L200,232'),
  _SvgSector(MuscleGroup.shoulders, false,
      'M202,228L210,220L221,215L231,207L242,211L252,219L259,230L262,242L265,254L264,268L261,280L250,271L240,264L231,257L220,249L208,238L202,228'),
  _SvgSector(MuscleGroup.shoulders, false,
      'M100,229L91,237L83,245L74,255L64,261L52,270L38,282L36,268L36,255L37,241L41,228L48,216L61,209L74,210L84,217L100,229'),
  _SvgSector(MuscleGroup.traps, false,
      'M149,161L134,155L132,166L129,176L120,186L107,192L93,198L81,203L70,207L86,214L96,221L103,230L108,244L112,257L117,272L122,287L129,301L135,313L141,326L150,339L157,326L164,311L171,296L179,281L184,267L188,251L195,238L198,227L209,216L220,212L228,206L214,201L202,197L192,191L180,186L171,178L168,168L166,156L149,161'),
  _SvgSector(MuscleGroup.glutes, false,
      'M149,450L143,436L136,424L125,414L113,408L100,405L87,411L81,423L78,437L76,450L74,466L73,480L76,493L84,504L96,510L111,513L127,511L140,503L148,493L158,501L166,508L178,513L192,513L206,508L217,498L224,484L226,464L224,449L222,433L218,419L211,409L197,405L185,409L174,415L165,427L157,439L149,450'),
  _SvgSector(MuscleGroup.hamstrings, false,
      'M181,517L178,527L176,540L173,555L171,569L170,584L169,599L169,614L169,631L170,645L173,659L177,675L185,661L192,648L197,637L202,627L207,643L215,656L215,635L216,622L217,605L219,590L220,576L221,561L220,543L218,530L207,519L193,516L181,517'),
  _SvgSector(MuscleGroup.hamstrings, false,
      'M115,515L103,515L91,520L84,527L79,539L80,555L80,573L81,589L82,604L84,621L84,636L83,650L82,662L94,646L97,632L105,641L112,656L120,674L126,656L126,637L129,620L132,604L130,587L129,566L127,548L123,533L115,515'),
  _SvgSector(MuscleGroup.calves, false,
      'M207,645L212,655L218,668L222,685L225,704L226,722L224,741L220,763L217,779L213,794L209,808L202,826L200,812L203,796L207,780L211,767L215,751L203,752L198,737L192,751L188,761L179,768L174,750L173,732L172,715L173,701L176,685L178,671L184,660L190,651L196,664L201,653L207,645'),
  _SvgSector(MuscleGroup.calves, false,
      'M101,734L105,746L112,759L120,767L125,748L128,729L127,712L125,695L123,682L117,669L110,655L103,664L98,653L92,646L86,658L82,675L79,691L77,706L74,727L77,749L81,769L84,785L87,800L96,819L97,804L95,788L92,776L86,755L96,751L101,734'),
  _SvgSector(MuscleGroup.forearms, false,
      'M269,398L269,381L270,367L275,354L283,373L287,389L290,408L292,427L296,444L299,459L289,463L275,465L268,448L261,434L256,421L250,407L245,395L241,382L238,358L250,371L257,381L269,398'),
  _SvgSector(MuscleGroup.forearms, false,
      'M25,349L28,362L31,381L31,402L38,388L47,374L61,357L58,379L54,394L47,412L39,429L33,446L26,465L13,464L1,459L6,441L8,421L9,403L12,385L16,367L25,349'),
  _SvgSector(MuscleGroup.triceps, false,
      'M265,364L267,345L270,330L271,313L267,295L262,282L251,272L240,263L231,256L227,271L224,285L223,297L225,310L228,323L232,337L237,350L245,361L253,370L253,354L248,339L246,326L245,314L254,307L259,321L262,336L265,364'),
  _SvgSector(MuscleGroup.triceps, false,
      'M35,361L33,348L29,330L31,313L33,296L38,281L51,271L60,264L71,256L73,269L76,286L76,303L73,320L69,335L64,348L56,360L46,371L50,352L55,336L55,321L48,310L41,319L37,336L35,361'),
];

// ─── Muscle Region ────────────────────────────────────────────────────────────
class _MuscleRegion {
  final MuscleGroup muscle;
  final Path path;
  final bool isFront;
  const _MuscleRegion(
      {required this.muscle, required this.path, required this.isFront});
}

class _BodyImages {
  final ui.Image maleFront, maleBack, femaleFront, femaleBack;
  const _BodyImages(
      {required this.maleFront,
      required this.maleBack,
      required this.femaleFront,
      required this.femaleBack});
}

Future<_BodyImages> _loadBodyImages() async {
  Future<ui.Image> load(String a) async {
    final d = await rootBundle.load(a);
    final c = await ui.instantiateImageCodec(d.buffer.asUint8List());
    return (await c.getNextFrame()).image;
  }

  return _BodyImages(
    maleFront: await load('assets/images/Mensfrontbody.png'),
    maleBack: await load('assets/images/Mensbackbody.png'),
    femaleFront: await load('assets/images/woomansfrontbody.png'),
    femaleBack: await load('assets/images/woomansbackbody.png'),
  );
}

class InteractiveMuscleSelector extends ConsumerStatefulWidget {
  final Function(Set<MuscleGroup>)? onSelectionChanged;
  final Set<MuscleGroup>? initialSelection;
  final bool isMale;
  const InteractiveMuscleSelector(
      {super.key, this.onSelectionChanged, this.initialSelection, this.isMale = true});

  @override
  ConsumerState<InteractiveMuscleSelector> createState() =>
      _InteractiveMuscleSelectorState();
}

class _InteractiveMuscleSelectorState
    extends ConsumerState<InteractiveMuscleSelector>
    with TickerProviderStateMixin {
  late AnimationController _flip;
  late Animation<double> _flipAnim;

  bool _showFront = true;
  bool _flipping = false;
  _BodyImages? _images;
  List<_MuscleRegion> _regions = [];
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _flipAnim = CurvedAnimation(parent: _flip, curve: Curves.easeInOut);
    _loadBodyImages().then((imgs) {
      if (!mounted) return;
      setState(() => _images = imgs);
    });

    if (widget.initialSelection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(muscleSelectionProvider.notifier)
            .setMuscles(widget.initialSelection!);
      });
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(InteractiveMuscleSelector old) {
    super.didUpdateWidget(old);
    if (old.isMale != widget.isMale && _lastSize != Size.zero) {
      setState(() => _regions = _buildRegions(_lastSize));
    }
  }

  List<_MuscleRegion> _buildRegions(Size sz) {
    final sectors = widget.isMale
        ? [..._maleFront, ..._maleBack]
        : [..._femaleFront, ..._femaleBack];
    return sectors.map((s) {
      final bounds = s.isFront
          ? (widget.isMale ? _maleFrontBounds : _femaleFrontBounds)
          : (widget.isMale ? _maleBackBounds : _femaleBackBounds);
      return _MuscleRegion(
        muscle: s.muscle,
        path: _parseSvgPath(s.d, bounds, sz.width, sz.height),
        isFront: s.isFront,
      );
    }).toList();
  }



  void _doFlip() async {
    if (_flipping) return;
    _flipping = true;
    await _flip.forward();
    setState(() => _showFront = !_showFront);
    _flip.reset();
    _flipping = false;
  }

  void _onTap(TapUpDetails d) {
    if (_regions.isEmpty) return;
    for (final r in _regions.reversed) {
      if (r.isFront != _showFront) continue;
      if (r.path.contains(d.localPosition)) {
        HapticFeedback.selectionClick();
        ref.read(muscleSelectionProvider.notifier).toggleMuscle(r.muscle);
        widget.onSelectionChanged
            ?.call(ref.read(muscleSelectionProvider).selectedMuscles);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(muscleSelectionProvider);
    ref.listen(muscleSelectionProvider,
        (_, n) => widget.onSelectionChanged?.call(n.selectedMuscles));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(children: [
        _header(state),
        Expanded(child: _canvas(state)),
      ]),
    );
  }

  Widget _header(MuscleSelectionState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(children: [
        const Icon(Icons.accessibility_new,
            color: AppTheme.primaryBrand, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Target Muscles',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            Text(
                state.selectedMuscles.isEmpty
                    ? 'Tap a muscle  ·  Swipe to rotate'
                    : '${state.selectedMuscles.length} selected  ·  Swipe to rotate',
                style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ]),
        ),
        if (state.selectedMuscles.isNotEmpty) ...[
          GestureDetector(
            onTap: () =>
                ref.read(muscleSelectionProvider.notifier).clearSelection(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('Clear',
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
            ),
          ),
          const SizedBox(width: 8),
        ],
        _FlipPill(isFront: _showFront, onTap: _doFlip),
      ]),
    );
  }

  Widget _canvas(MuscleSelectionState state) {
    return LayoutBuilder(builder: (ctx, box) {
      final paintW =
          (box.maxHeight * 0.4705).clamp(100.0, box.maxWidth.toDouble());
      final size = Size(paintW, box.maxHeight);
      if (size != _lastSize) {
        _lastSize = size;
        _regions = _buildRegions(size);
      }
      return Stack(children: [
        Center(
          child: SizedBox(
            width: paintW,
            height: box.maxHeight,
            child: GestureDetector(
              onTapUp: _onTap,
              onHorizontalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0).abs() > 80) _doFlip();
              },
              child: AnimatedBuilder(
                animation: _flipAnim,
                builder: (_, __) {
                  final t = _flipAnim.value;
                  final angle = t < 0.5 ? t * pi : (t - 1.0) * pi;
                  final front = _flipping
                      ? (t < 0.5 ? _showFront : !_showFront)
                      : _showFront;
                  final img = _images == null
                      ? null
                      : front
                          ? (widget.isMale
                              ? _images!.maleFront
                              : _images!.femaleFront)
                          : (widget.isMale
                              ? _images!.maleBack
                              : _images!.femaleBack);
                  return Stack(children: [
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateY(angle),
                      child: CustomPaint(
                        size: size,
                        painter: _BodyPainter(
                          image: img,
                          regions: _regions,
                          selected: state.selectedMuscles,
                          isFront: front,
                        ),
                      ),
                    ),
                    if (_images == null)
                      const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primaryBrand, strokeWidth: 2)),
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chevron_left,
                                color: Colors.white.withValues(alpha: 0.18),
                                size: 16),
                            const SizedBox(width: 4),
                            Text('swipe to rotate',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    fontSize: 9)),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right,
                                color: Colors.white.withValues(alpha: 0.18),
                                size: 16),
                          ]),
                    ),
                  ]);
                },
              ),
            ),
          ),
        ),
        if (state.selectedMuscles.isNotEmpty)
          Positioned(left: 8, top: 8, bottom: 8, child: _chips(state)),
      ]);
    });
  }

  Widget _chips(MuscleSelectionState state) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: state.selectedMuscles.map((m) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 280),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(
                  scale: v, alignment: Alignment.centerLeft, child: child),
              child: GestureDetector(
                onTap: () => ref
                    .read(muscleSelectionProvider.notifier)
                    .deselectMuscle(m),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: m.color.withValues(alpha: 0.75), width: 1.2),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: m.color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: m.color, blurRadius: 4)
                            ])),
                    const SizedBox(width: 5),
                    Text(m.displayName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 3),
                    Icon(Icons.close,
                        color: m.color.withValues(alpha: 0.6), size: 10),
                  ]),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FlipPill extends StatelessWidget {
  final bool isFront;
  final VoidCallback onTap;
  const _FlipPill({required this.isFront, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.primaryBrand.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: AppTheme.primaryBrand.withValues(alpha: 0.65), width: 1.1),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
          child: Text(isFront ? 'FRONT' : 'BACK',
              key: ValueKey(isFront),
              style: const TextStyle(
                  color: AppTheme.primaryBrand,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8)),
        ),
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  final ui.Image? image;
  final List<_MuscleRegion> regions;
  final Set<MuscleGroup> selected;
  final bool isFront;

  const _BodyPainter({
    required this.image,
    required this.regions,
    required this.selected,
    required this.isFront,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) return;
    final full = Offset.zero & size;
    final src =
        Rect.fromLTWH(0, 0, image!.width.toDouble(), image!.height.toDouble());

    // 1. Draw the fully colored base image.
    canvas.drawImageRect(
        image!, src, full, Paint()..filterQuality = FilterQuality.medium);

    // 2. Identify all unselected muscle paths for the current view.
    final unselectedPath = Path();
    for (final r in regions) {
      if (r.isFront == isFront && !selected.contains(r.muscle)) {
        unselectedPath.addPath(r.path, Offset.zero);
      }
    }

    // 3. Darken ONLY the unselected muscles.
    if (!unselectedPath.getBounds().isEmpty) {
      canvas.saveLayer(full, Paint());
      
      canvas.drawPath(
        unselectedPath,
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.40),
      );
      
      // Mask the darkening to the actual body silhouette
      canvas.drawImageRect(
          image!,
          src,
          full,
          Paint()
            ..blendMode = BlendMode.dstIn
            ..filterQuality = FilterQuality.medium);
            
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BodyPainter old) =>
      old.image != image ||
      !setEquals(old.selected, selected) ||
      old.isFront != isFront ||
      old.regions.length != regions.length;
}
