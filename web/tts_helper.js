// Web用のTTSヘルパー関数
window.ttsHelper = {
  // 日本語音声を取得
  getJapaneseVoice: function() {
    const voices = window.speechSynthesis.getVoices();
    console.log('利用可能な音声:', voices.map(v => v.name + ' (' + v.lang + ')'));

    // 日本語音声を優先的に探す
    const japaneseVoice = voices.find(voice =>
      voice.lang === 'ja-JP' ||
      voice.lang.startsWith('ja') ||
      voice.name.toLowerCase().includes('japan')
    );

    if (japaneseVoice) {
      console.log('日本語音声を使用:', japaneseVoice.name);
      return japaneseVoice;
    }

    console.warn('日本語音声が見つかりません。デフォルトを使用します。');
    return null;
  },

  // テキストを読み上げ
  speak: function(text, rate = 1.0, pitch = 1.0, volume = 1.0) {
    // 既存の読み上げを停止
    window.speechSynthesis.cancel();

    const utterance = new SpeechSynthesisUtterance(text);

    // 日本語音声を設定
    const japaneseVoice = this.getJapaneseVoice();
    if (japaneseVoice) {
      utterance.voice = japaneseVoice;
      utterance.lang = japaneseVoice.lang;
    } else {
      utterance.lang = 'ja-JP';
    }

    // パラメータ設定
    utterance.rate = rate;
    utterance.pitch = pitch;
    utterance.volume = volume;

    // イベントハンドラ
    utterance.onstart = function() {
      console.log('読み上げ開始');
    };

    utterance.onend = function() {
      console.log('読み上げ完了');
    };

    utterance.onerror = function(event) {
      console.error('読み上げエラー:', event);
    };

    // 読み上げ開始
    window.speechSynthesis.speak(utterance);

    console.log('読み上げるテキスト:', text.substring(0, 100) + '...');
  },

  // 読み上げを停止
  stop: function() {
    window.speechSynthesis.cancel();
    console.log('読み上げ停止');
  },

  // 読み上げを一時停止
  pause: function() {
    window.speechSynthesis.pause();
    console.log('読み上げ一時停止');
  },

  // 読み上げを再開
  resume: function() {
    window.speechSynthesis.resume();
    console.log('読み上げ再開');
  }
};

// 音声リストが更新されたときに再取得
window.speechSynthesis.onvoiceschanged = function() {
  console.log('音声リストが更新されました');
  window.ttsHelper.getJapaneseVoice();
};