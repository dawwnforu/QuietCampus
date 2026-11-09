import 'package:characters/characters.dart';

import 'model.dart';

enum RabbitMood { starry, listening, thoughtful, gentle }

class RabbitStory {
  const RabbitStory(this.text, this.mood, this.gesture);
  final String text;
  final RabbitMood mood;
  final String gesture;
}

RabbitStory rabbitStory(Entry entry, {String name = '', bool english = false}) {
  final who = name.trim().isEmpty
      ? (english ? 'You' : '你')
      : name.trim().characters.take(20).join();
  final body = entry.plainText.trim();
  // Keep each record's direction stable across rebuilds without storing derived text.
  final variant = entry.id.codeUnits.fold(0, (sum, unit) => sum + unit);
  String direction(List<String> choices) {
    final chosen = choices[variant % choices.length];
    return '【${english ? _englishGestures[chosen]! : chosen}】';
  }

  // shortcut: deterministic local preview, not semantic inference; replace only after on-device model evaluation and user controls are ready.
  final first = body.split(RegExp(r'[。！？!?\n]')).first.trim();
  final uncertain =
      RegExp(r'^[^。！!\n]*[？?]').hasMatch(body) ||
      RegExp(r'[「」“”"?？]|如果|假如|希望|打算|想要|下次|还没|没有|没能|不敢|并未|并没有|未能')
          .hasMatch(first);
  if (!uncertain &&
      RegExp(r'^(?:今天)?(?:我)?第一次在读书会上发言(?:了)?$').hasMatch(first)) {
    return RabbitStory(
      english
          ? '$who spoke at the book club for the first time. I’m giving that brave step a little round of applause.'
          : '$who第一次在读书会上发言啦！这一步真棒，我想为这份勇气认真鼓掌。',
      RabbitMood.starry,
      direction(const [
        '小兔踮起脚尖，两只小爪子拍得格外认真',
        '小兔眼睛一亮，嘴角藏不住地往上翘',
        '小兔把两只爪子攥成小拳头，耳尖也跟着扬起来',
        '小兔郑重地点点头，悄悄给这一页画了一颗星',
      ]),
    );
  }
  if (!uncertain &&
      RegExp(r'^(?:今天)?我(?:很|有点|真的|感到|觉得)?(?:难过|失落|委屈|疲惫|累|伤心)')
          .hasMatch(first)) {
    return RabbitStory(
      english
          ? '$who wrote down a difficult moment. There’s no need to rush past it; I can sit with this page for a while.'
          : '$who把不太好受的这一刻写了下来。不用急着振作，我愿意陪这一页多待一会儿。',
      RabbitMood.gentle,
      direction(const [
        '小兔往旁边挪了挪，留出一个安静的位置',
        '小兔放轻了声音，把没说完的话好好接住',
        '小兔轻轻合上本子，安静地陪着，没有催促',
        '小兔把爪子收在围巾下面，连翻页都放得很轻',
      ]),
    );
  }
  if (!uncertain && first.startsWith('我负责')) {
    final work = first.substring(3).characters.take(42).join();
    final tail = first.substring(3).characters.length > 42 ? '…' : '';
    return RabbitStory(
      english
          ? '$who described a responsibility: $work$tail. I’ve kept a place for this experience in my little notebook.'
          : '$who记下了自己负责的事：$work$tail。我把这段经历收进小本子啦。',
      RabbitMood.listening,
      direction(const [
        '小兔扶正小本子，一笔一画记下这段经历',
        '小兔听得很认真，爪尖停在刚刚翻开的那一页',
        '小兔微微前倾，把这段经历郑重地收好',
        '小兔给这一页折了个小角，神情比平时还认真',
      ]),
    );
  }
  if (entry.kind == 'project' && first.startsWith('目标：')) {
    final goal = first.substring(3).characters.take(42).join();
    final tail = first.substring(3).characters.length > 42 ? '…' : '';
    return RabbitStory(
      english
          ? '$who set down a project goal: $goal$tail. I’d like to see how it grows, one page at a time.'
          : '$who给项目写下了目标：$goal$tail。我也想看看它慢慢长大。',
      RabbitMood.thoughtful,
      direction(const [
        '小兔用爪尖托住下巴，替这个新点子留下一枚书签',
        '小兔歪着脑袋，目光在那行目标上多停了一会儿',
        '小兔把铅笔轻轻转了半圈，像在给念头腾地方',
        '小兔摊开空白页，耳朵一前一后，认真琢磨起来',
      ]),
    );
  }
  return RabbitStory(
    english
        ? '$who added another ${switch (entry.kind) {
            'project' => 'project page',
            'experience' => 'experience',
            _ => 'journal page',
          }}. Open it whenever you’re ready to look back.'
        : '$who又留下一页${entry.kindLabel}。点开这一页，一起慢慢看看吧。',
    RabbitMood.listening,
    direction(const [
      '小兔轻轻压平纸角，给这一页留了个位置',
      '小兔抱着本子坐稳，目光落在新添的那一页',
      '小兔把书签往里推了推，准备慢慢往下读',
      '小兔抚了抚围巾，安安静静地守在页边',
    ]),
  );
}

const _englishGestures = {
  '小兔踮起脚尖，两只小爪子拍得格外认真':
      'The rabbit rises on tiptoe and claps with both little paws',
  '小兔眼睛一亮，嘴角藏不住地往上翘':
      'The rabbit’s eyes light up, a smile creeping across its face',
  '小兔把两只爪子攥成小拳头，耳尖也跟着扬起来':
      'The rabbit curls its paws into tiny fists, ears lifting too',
  '小兔郑重地点点头，悄悄给这一页画了一颗星':
      'The rabbit nods solemnly and draws a small star beside the page',
  '小兔往旁边挪了挪，留出一个安静的位置':
      'The rabbit shuffles over, leaving a quiet space beside it',
  '小兔放轻了声音，把没说完的话好好接住':
      'The rabbit lowers its voice and waits for the unfinished words',
  '小兔轻轻合上本子，安静地陪着，没有催促':
      'The rabbit closes its notebook softly and stays, without hurrying',
  '小兔把爪子收在围巾下面，连翻页都放得很轻':
      'The rabbit tucks its paws under its scarf and turns the page softly',
  '小兔扶正小本子，一笔一画记下这段经历':
      'The rabbit straightens its notebook and writes with care',
  '小兔听得很认真，爪尖停在刚刚翻开的那一页':
      'The rabbit listens closely, one paw resting on the open page',
  '小兔微微前倾，把这段经历郑重地收好':
      'The rabbit leans forward, giving this memory its full attention',
  '小兔给这一页折了个小角，神情比平时还认真':
      'The rabbit folds a tiny corner, looking especially thoughtful',
  '小兔用爪尖托住下巴，替这个新点子留下一枚书签':
      'The rabbit rests its chin on a paw and bookmarks the new idea',
  '小兔歪着脑袋，目光在那行目标上多停了一会儿':
      'The rabbit tilts its head and lingers over the goal',
  '小兔把铅笔轻轻转了半圈，像在给念头腾地方':
      'The rabbit turns its pencil slowly, making room for a thought',
  '小兔摊开空白页，耳朵一前一后，认真琢磨起来':
      'The rabbit opens a blank page, ears tilted as it thinks',
  '小兔轻轻压平纸角，给这一页留了个位置':
      'The rabbit smooths the paper’s corner, making a place for this page',
  '小兔抱着本子坐稳，目光落在新添的那一页':
      'The rabbit settles with its notebook and looks at the new page',
  '小兔把书签往里推了推，准备慢慢往下读':
      'The rabbit nudges its bookmark inward, ready to read slowly',
  '小兔抚了抚围巾，安安静静地守在页边':
      'The rabbit smooths its scarf and waits quietly beside the page',
};
