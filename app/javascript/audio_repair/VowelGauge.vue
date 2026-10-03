<template>
  <div>
    <div class="relative rounded bg-gradient-to-r from-red-100 via-amber-50 to-emerald-100"
         :class="compact ? 'h-4' : 'h-7'">
      <!-- the ambiguous middle -->
      <div class="absolute inset-y-0 bg-white/60 border-x border-dashed border-gray-300"
           :style="{ left: pct(4) + '%', right: (100 - pct(-4)) + '%' }"></div>

      <!-- before -->
      <div v-if="before != null"
           class="absolute top-0 bottom-0 w-px bg-gray-400"
           :style="{ left: pct(before) + '%' }"
           :title="`before: ${before} dB`"></div>
      <div v-if="before != null && !compact"
           class="absolute -top-0.5 text-[9px] text-gray-400 -translate-x-1/2"
           :style="{ left: pct(before) + '%' }">before</div>

      <!-- after -->
      <div v-if="after != null"
           class="absolute rounded-full border-2 border-white shadow"
           :class="[compact ? 'w-3 h-3 top-0.5' : 'w-4 h-4 top-1.5', dotColour]"
           :style="{ left: `calc(${pct(after)}% - ${compact ? 6 : 8}px)` }"
           :title="`after: ${after} dB`"></div>

      <!-- travel -->
      <div v-if="before != null && after != null"
           class="absolute top-1/2 h-px bg-gray-500/50"
           :style="travelStyle"></div>
    </div>

    <div v-if="!compact" class="flex justify-between text-[10px] text-gray-500 mt-1">
      <span class="flex items-center gap-1">
        <span class="digitalkhatt-v2" style="font-size:14px;line-height:1">ـُ</span>
        <span>rounded (u)</span>
      </span>
      <span>ambiguous</span>
      <span class="flex items-center gap-1">
        <span>front (i)</span>
        <span class="digitalkhatt-v2" style="font-size:14px;line-height:1">ـِ</span>
      </span>
    </div>
  </div>
</template>

<script>
// f2_balance runs roughly +18 dB (clearly [u]) to -18 dB (clearly [i]).
// Left of the bar is [u], right is [i], so position is an inverted mapping.
const RANGE = 18;

export default {
  name: "VowelGauge",
  props: {
    before: { type: Number, default: null },
    after: { type: Number, default: null },
    compact: { type: Boolean, default: false }
  },
  computed: {
    dotColour() {
      if (this.after == null) return "bg-gray-400";
      if (this.after < -4) return "bg-emerald-500";
      if (this.after > 4) return "bg-red-500";
      return "bg-amber-500";
    },
    travelStyle() {
      const a = this.pct(this.before);
      const b = this.pct(this.after);
      return { left: Math.min(a, b) + "%", width: Math.abs(b - a) + "%" };
    }
  },
  methods: {
    pct(balance) {
      const clamped = Math.max(-RANGE, Math.min(RANGE, balance ?? 0));
      return ((RANGE - clamped) / (2 * RANGE)) * 100;
    }
  }
};
</script>
