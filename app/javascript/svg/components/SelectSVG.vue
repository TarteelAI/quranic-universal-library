<template>
  <div>
    <div id="dropzone"
         @drop="onDrop">
      <label class="message" for="input">
        Drop SVG file here or click to upload.
        <input type="file" id="input" @change="onInputChange" accept="image/svg+xml"/>
      </label>

      <div id="preview" v-if="fileLoaded">
        <img :src="previewPath"/>
        <p class="info">
          <strong>Name</strong>{{ fileName }}
          <strong>Size</strong>{{ formatBytes(fileSize)}}
        </p>
      </div>
    </div>
  </div>
</template>

<script>
import {mapState} from 'vuex'

const events = ['dragenter', 'dragover', 'dragleave', 'drop']

export default {
  name: 'SelectSVG',
  mounted() {
    events.forEach((name) => {
      document.body.addEventListener(name, this.prevent)
    })
  },
  unmounted() {
    events.forEach((name) => {
      document.body.removeEventListener(name, this.prevent)
    })
  },
  computed: {
    ...mapState([
      'file',
      'fileName',
      'fileSize'
    ]),
    fileLoaded() {
      return !!this.file;
    },
    previewPath() {
      return URL.createObjectURL(this.file)
    },
  },
  methods: {
    prevent(e) {
      e.preventDefault();
      e.stopImmediatePropagation();
    },
    onDrop(e) {
      this.handleFile(e.dataTransfer.files[0])
    },
    onInputChange(e) {
      this.handleFile(e.target.files[0])
    },
    handleFile(file) {
      this.$store.dispatch("LOAD_SVG_FILE", {file: file});
    },
    formatBytes(bytes) {
      if (bytes === 0) return '0 Bytes';
      const k = 1024;
      const dm = 2
      const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
      const i = Math.floor(Math.log(bytes) / Math.log(k));

      return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
    }
  }
}
</script>

<style>
#dropzone {
  border: 2px dashed #0087F7;
  border-radius: 5px;
  text-align: center;
  padding: 16px;
  width: 100%;
  max-width: 800px;
  margin: 0 auto;
  background: white;
  box-shadow: rgba(50, 50, 93, 0.25) 0px 50px 100px -20px, rgba(0, 0, 0, 0.3) 0px 30px 60px -30px;
  transition: .2s ease;
}

#dropzone:hover {
  border-style: solid;
}

#input {
  position: absolute !important;
  width: 1px !important;
  height: 1px !important;
  padding: 0 !important;
  margin: -1px !important;
  overflow: hidden !important;
  clip: rect(0, 0, 0, 0) !important;
  white-space: nowrap !important;
  border: 0 !important;
}

label {
  width: 100%;
  height: 60px;
  padding-top: 20px;
}

#preview img {
  max-width: 150px;
  max-height: 150px;
}

strong {
  margin: 0 5px;
}

.info{
  margin: 10px 0 0 0;
}
</style>