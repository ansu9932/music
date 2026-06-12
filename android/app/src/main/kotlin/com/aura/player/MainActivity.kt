package com.aura.player

import com.ryanheise.audioservice.AudioServiceActivity

// audio_service requires the host Activity to extend AudioServiceActivity so
// that media-button intents and the foreground service bind correctly.
class MainActivity : AudioServiceActivity()
