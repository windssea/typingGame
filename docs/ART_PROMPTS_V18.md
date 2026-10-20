# 1.8 Image Gen / Grok 提示与制作约束

工具：内置 image_gen；透明素材请求 `transparent_background=true`，场景为 false。原图保留在 `art-sources-v18/`。不以生成图作为 HUD 或目标文字，界面文字由 Godot 渲染。下列为各资产的生产提示说明；完整 Grok 提示原文保留在 `assets/animation-sources/*-v18/motion*.txt`。

## 皇家场景

Premium original American animated cartoon game battlefield background, landscape 16:9. Bright inviting sapphire gold ivory royal fantasy, rounded clean painterly forms and precise crisp materials. Camera elevated three-quarter. Two horizontal grass lanes across middle at 35 and 70 percent height, separated by a blue river vertical at center with two stone bridges, small distant friendly castle on left edge and red-roof opponent castle on right edge. Preserve 75% open grass for moving units. Soft depth, dynamic composition, no characters no UI no text no letters no circles no guides. Product quality cohesive children's keyboard battle game.

## 深海场景

Premium original American animated cartoon game background, landscape 16:9, underwater exploration arena. Luminous turquoise to deep sapphire ocean with sunny surface strip at top, distant coral reef silhouettes and rock arches at left and right edges, clear open water through center 75% of frame. Friendly adventurous children game, refined painterly rounded forms, crisp coral details, volumetric sunbeams. No submarines no fish actors no UI no text no words no circles.

## 餐厅场景

Premium original American animated cartoon cooking game background landscape16:9. Bright charming modern fantasy cafe open kitchen, three service counters in foreground at equal horizontal spacing, warm peach mint teal gold palette, distant window garden, overhead copper pendant lights, clean polished wood counters. Eye-level wide game camera, open action space above three counters for chefs dishes and order words. No people no food actors no UI no text no letters. Refined professional animated feature art, rounded forms, soft controlled outlines.

## 角色与炮台母版

Production sprite sheet on genuinely transparent background, premium original American animated cartoon game art, 3 by2 uniform grid six separate sprites with ample transparent gaps, each fully inside its cell, no shadow touching neighbors, no text. Top left small sapphire gold armored friendly knight running right with sword, top middle red gold round shield goblin facing left, top right cheerful compact yellow turquoise submarine facing right with propeller and glass cockpit. Bottom left cheerful chef girl white toque teal apron full body holding pan, bottom middle small sapphire mechanical aiming cannon side profile barrel aimed straight up, bottom right friendly cream teal robot full body in energetic running pose. Crisp sophisticated painted 2D sprites consistent upper-left light, clean silhouette, no circles no ground no UI.

## 极速跑道

Premium original American animated cartoon game environment, landscape 16:9, vibrant sunny futuristic school athletics garden with a curving teal gold running track across bottom third, distant friendly academy workshop and elegant trees at the left and right edges, clear calm light turquoise blue open sky filling central 70% for large editable typing words and timer. Sophisticated luminous painted 2D game art, fresh mint sapphire butter gold, crisp soft materials, controlled details, no characters no props in middle no billboards no clocks no typography no numbers no UI. Camera fixed side view, track footline horizontal at 80% height.

## 餐点与顾客

Premium original American cartoon cooking game production asset sheet, genuine transparent background. Exactly 3 columns by2 rows, uniform cells with 18% empty transparent gutters, each subject fully isolated inside own cell, no parts crossing cell boundaries. Top row: left a small ivory porcelain plate with fluffy golden pancakes, strawberry and maple syrup; middle a small ivory plate with colorful pasta tomato and basil; right a small ivory plate with golden omelette and vegetables. Bottom row: left cheerful young boy cafe customer portrait head and shoulders blue shirt; middle cheerful young girl cafe customer portrait head and shoulders coral shirt; right friendly elderly grandpa customer portrait head and shoulders mint shirt. Cohesive refined painted animated feature quality, warm natural skin, charming expressive faces, mint sapphire butter gold accents, upper-left light, crisp edges. No ground no shadows outside cells no panels no UI no text no numbers no letters.

## 独立云层

One isolated wide fluffy fair-weather cloud sprite on genuinely transparent background, premium original American cartoon game art. Elegant layered soft rounded cloud volumes with luminous warm ivory highlights above and very pale cool blue shadows beneath, clean delicate painted edge, subtle internal detail, naturally uneven silhouette, three main lobes, horizontal shape about 3:1, plenty of empty transparent margin on all sides. No scenery no sky background no ground shadow no characters no text no frame no stars.

## 导入约束

角色母版为 1536×1024，按实际边界切片，第一行裁到 y480 排除下一行碎片；透明画布 448×448、主体最长384。菜单与战场采用同一母版。食物实际 y0–420、人物 y430–1024，并非盲信生成网格。帧图集统一256格、固定裁切与8像素留白；原生24fps。云母版保留2172×724，运行768×256。PNG 开启 mipmaps，缩小时线性过滤。原图 alpha 最大值254是工具输出特性，判定透明边界用实际 alpha，不强制255。
