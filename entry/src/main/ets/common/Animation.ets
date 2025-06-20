import { curves } from "@kit.ArkUI"


export let AppearDisappearAni = TransitionEffect.OPACITY
  .combine(
    TransitionEffect.asymmetric(
      TransitionEffect.scale({ x: 1.05, y: 1.05 }),
      TransitionEffect.scale({ x: 0.98, y: 0.98 })
    )
  ).animation({ duration: 100 })

export class ClickDarkenEffect implements AttributeModifier<CommonAttribute> {
  applyNormalAttribute(instance: CommonAttribute): void {
    instance.backgroundEffect({
      radius: 0,
      brightness: 1
    })
  }

  applyPressedAttribute(instance: CommonAttribute): void {
    instance.backgroundEffect({
      radius: 0,
      brightness: 0.85
    })
  }
}

export let MenuFlyDownAni = TransitionEffect.OPACITY
  .animation({ duration: 120, curve: Curve.EaseIn })
  .combine(
    TransitionEffect.translate({ y: -50 })
  ).animation({ duration: 100 })

export let MenuFlyUpAni = TransitionEffect.OPACITY
  .animation({ duration: 120, curve: Curve.EaseIn })
  .combine(
    TransitionEffect.translate({ y: 50 })
  ).animation({ duration: 100 })

export let AvatarTransition: AnimateParam = {
  duration: 300, curve: Curve.ExtremeDeceleration
}

export let OpacityTransition = TransitionEffect.OPACITY.animation({ duration: 300, curve: Curve.ExtremeDeceleration })

export let SpringCurve: AnimateParam = { curve: curves.springMotion(0.35) }

export const HeavyClickEffect: ClickEffect = { level: ClickEffectLevel.HEAVY, scale: 0.7 }

interface AniDuration {
  ratio: number
  spring: number
  ms50: number
  ms120: number
  ms150: number
  ms200: number
  ms300: number
}

export let AniSpeed: AniDuration

export function AnimationSetUp(ratio: number) {
  const speed: AniDuration = {
    ratio: ratio,
    spring: Math.max(0.32 * ratio, 0.01),
    ms50: 50 * ratio,
    ms120: 120 * ratio,
    ms150: 150 * ratio,
    ms200: 200 * ratio,
    ms300: 300 * ratio
  }

  AppearDisappearAni = TransitionEffect.OPACITY
    .combine(
      TransitionEffect.asymmetric(
        TransitionEffect.scale({ x: 1.05, y: 1.05 }),
        TransitionEffect.scale({ x: 0.98, y: 0.98 })
      )
    ).animation({ duration: speed.ms120 })

  MenuFlyDownAni = TransitionEffect.OPACITY
    .animation({ duration: speed.ms150, curve: Curve.EaseIn })
    .combine(
      TransitionEffect.translate({ y: -50 })
    ).animation({ duration: speed.ms120 })

  MenuFlyUpAni = TransitionEffect.OPACITY
    .animation({ duration: speed.ms150, curve: Curve.EaseIn })
    .combine(
      TransitionEffect.translate({ y: 50 })
    ).animation({ duration: speed.ms120 })

  AvatarTransition = {
    duration: speed.ms300, curve: Curve.ExtremeDeceleration
  }

  OpacityTransition = TransitionEffect.OPACITY.animation({ duration: speed.ms300, curve: Curve.ExtremeDeceleration })

  SpringCurve = { curve: curves.springMotion(speed.spring) }

  AniSpeed = speed
}

AnimationSetUp(1)