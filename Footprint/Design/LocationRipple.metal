#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// 两三圈水透镜从地点荡开。
// 圈内向圆心取样，画面放大；半径附近窄带反向挤压，形成亮边。
// 盘内不透明，只在外缘羽化。时间与 LocationWaterRipple.fillRippleMask 对齐。
// 第三圈 0.96s 出发，1.85s 后消失。

[[ stitchable ]] half4 locationRipple(float2 position, SwiftUI::Layer layer, float2 center, float time) {
    float2 delta = position - center;
    float dist = length(delta);
    float2 dir = dist > 1.0 ? delta / dist : float2(0.0);
    float2 sample = position;
    float mask = 0.0;

    for (int i = 0; i < 3; ++i) {
        float age = time - float(i) * 0.48;
        if (age <= 0.0) continue;

        float radius = 36.0 + age * 72.0;
        float appear = smoothstep(0.0, 0.12, age);
        float life = 1.0 - smoothstep(1.35, 1.85, age);
        float edge = 1.0 - smoothstep(210.0, 255.0, radius);
        float fade = appear * life * edge;
        if (fade <= 0.001) continue;

        float bowl = 1.0 - smoothstep(radius * 0.12, radius * 0.92, dist);
        sample -= dir * dist * (0.28 * bowl * fade);

        float band = dist - radius;
        float crest = exp(-band * band / (2.0 * 11.0 * 11.0));
        float side = band >= 0.0 ? 1.1 : -0.9;
        sample += dir * crest * fade * 36.0 * side;

        float disc = (1.0 - smoothstep(radius - 2.0, radius + 28.0, dist)) * fade;
        mask = max(mask, disc);
    }

    half4 color = layer.sample(sample);
    color *= half(saturate(mask));
    return color;
}
