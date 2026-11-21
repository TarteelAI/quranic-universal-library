import type { SharedProps } from '@/types/serializers'

type FlashData = {
  notice?: string
  alert?: string
}

declare module '@inertiajs/core' {
  export interface InertiaConfig {
    sharedPageProps: SharedProps
    flashDataType: FlashData
    errorValueType: string[]
  }
}
