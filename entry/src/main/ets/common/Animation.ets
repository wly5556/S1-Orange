import { curves } from '@kit.ArkUI'

export const AppearDisappearAni = TransitionEffect.OPACITY
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

export const MenuFlyDownAni = TransitionEffect.OPACITY
  .animation({ duration: 120, curve: Curve.EaseIn })
  .combine(
    TransitionEffect.translate({ y: -50 })
  ).animation({ duration: 100 })

export const MenuFlyUpAni = TransitionEffect.OPACITY
  .animation({ duration: 120, curve: Curve.EaseIn })
  .combine(
    TransitionEffect.translate({ y: 50 })
  ).animation({ duration: 100 })

export const AvatarTransition: AnimateParam = {
  duration: 300, curve: Curve.ExtremeDeceleration
}

export const OpacityTransition = TransitionEffect.OPACITY.animation({ duration: 300, curve: Curve.ExtremeDeceleration })

export const Spring035s: AnimateParam = { curve: curves.springMotion(0.35) }

export const HeavyClickEffect: ClickEffect = { level: ClickEffectLevel.HEAVY, scale: 0.7 }