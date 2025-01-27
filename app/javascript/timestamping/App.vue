<template>
  <div class="tw-min-h-screen tw-bg-gray-50">
    <div class="tw-container tw-mx-auto tw-px-4 tw-py-8">
      <Alert />
      <SelectAudioSrc class="tw-mb-8" />
      <ActionBar class="tw-mb-8" />
      <Verse />
    </div>
  </div>
</template>

<script setup>
import { onMounted } from 'vue'
import { useSurahStore } from '@/stores/surah.store'
import { useAudioStore } from '@/stores/audio.store'
import { useSegmentsStore } from '@/stores/segments.store'
import { useUiStore } from '@/stores/ui.store'
import SelectAudioSrc from '@/components/SelectAudioSrc.vue'
import Alert from '@/components/Alert.vue'
import ActionBar from '@/components/ActionBar.vue'
import Verse from '@/components/Verse.vue'

const surahStore = useSurahStore()
const audioStore = useAudioStore()
const segmentsStore = useSegmentsStore()
const uiStore = useUiStore()

// Initialize stores with dataset values
const initStore = () => {
  const parentEl = document.getElementById('app')
  const dataset = parentEl.dataset

  surahStore.initialize({
    chapter: dataset.chapter || 1,
    versesCount: dataset.versesCount || 7,
    verse: dataset.verse || 1,
    recitation: dataset.recitation || 1,
    audioType: dataset.audioType || 'chapter',
    segmentLocked: dataset.segmentLocked || 'false',
    segmentsUrl: dataset.segmentsUrl || 'surah_audio_files',
    autoPlay: dataset.autoPlay || 'false'
  })

  audioStore.setSource({
    url: dataset.audioUrl || '',
    fromFile: false
  })

  uiStore.toggleSetting('showSegments', dataset.showSegments === 'true')
}

// Load initial segments data
const loadSegments = async () => {
  try {
    await surahStore.loadSegments()
  } catch (error) {
    uiStore.showAlert('Failed to load segments data')
  }
}

onMounted(() => {
  initStore()
  loadSegments()
})
</script>