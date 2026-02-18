#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 初始化词库：从上游拉取所有词库文件
# 用法: bash scripts/init-dicts.sh
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP_DIR=$(mktemp -d)
DEST="$REPO_ROOT/dicts"

echo "🏔️  开始初始化词库..."
echo "   临时目录: $TEMP_DIR"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 1. 克隆白霜拼音
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "❄️  正在拉取白霜拼音 (rime-frost)..."
git clone --depth 1 https://github.com/gaboolic/rime-frost.git "$TEMP_DIR/rime-frost"

# 字表 & 核心词库
echo "   → 同步字表和核心词库..."
cp "$TEMP_DIR/rime-frost/cn_dicts/8105.dict.yaml"  "$DEST/frost.8105.dict.yaml"
cp "$TEMP_DIR/rime-frost/cn_dicts/41448.dict.yaml" "$DEST/frost.41448.dict.yaml"
cp "$TEMP_DIR/rime-frost/cn_dicts/base.dict.yaml"  "$DEST/frost.base.dict.yaml"
cp "$TEMP_DIR/rime-frost/cn_dicts/ext.dict.yaml"   "$DEST/frost.ext.dict.yaml"

# 细胞词库
echo "   → 同步细胞词库..."
for file in "$TEMP_DIR/rime-frost/cn_dicts_cell"/*.dict.yaml; do
  filename=$(basename "$file")
  cp "$file" "$DEST/frost_cell.${filename}"
done

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2. 克隆雾凇拼音
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "🧊 正在拉取雾凇拼音 (rime-ice)..."
git clone --depth 1 https://github.com/iDvel/rime-ice.git "$TEMP_DIR/rime-ice"

# 腾讯词向量 + 杂项
echo "   → 同步腾讯词库和杂项..."
cp "$TEMP_DIR/rime-ice/cn_dicts/tencent.dict.yaml" "$DEST/rime_ice.tencent.dict.yaml"
cp "$TEMP_DIR/rime-ice/cn_dicts/others.dict.yaml"  "$DEST/rime_ice.others.dict.yaml"

# 英文词库
echo "   → 同步英文词库..."
cp "$TEMP_DIR/rime-ice/en_dicts/en.dict.yaml"     "$DEST/rime_ice.en.dict.yaml"
cp "$TEMP_DIR/rime-ice/en_dicts/en_ext.dict.yaml" "$DEST/rime_ice.en_ext.dict.yaml"

# OpenCC
echo "   → 同步 OpenCC 数据..."
cp "$TEMP_DIR/rime-ice/opencc"/* "$REPO_ROOT/opencc/"

# 中英混输
echo "   → 同步中英混输词库..."
[ -f "$TEMP_DIR/rime-ice/cn_dicts/cn_en.txt" ] && cp "$TEMP_DIR/rime-ice/cn_dicts/cn_en.txt" "$DEST/rime_ice.cn_en.txt" || true
[ -f "$TEMP_DIR/rime-ice/cn_dicts/cn_en_flypy.txt" ] && cp "$TEMP_DIR/rime-ice/cn_dicts/cn_en_flypy.txt" "$DEST/rime_ice.cn_en_flypy.txt" || true

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3. 清理旧的雾凇词库文件（已被白霜替代）
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "🧹 清理旧的词库文件..."
# 这些旧文件已被 frost.* 替代，可以安全删除
rm -f "$DEST/rime_ice.8105.dict.yaml"
rm -f "$DEST/rime_ice.41448.dict.yaml"
rm -f "$DEST/rime_ice.base.dict.yaml"
rm -f "$DEST/rime_ice.ext.dict.yaml"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4. 清理临时文件
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
rm -rf "$TEMP_DIR"

echo ""
echo "✅ 词库初始化完成!"
echo ""
echo "📊 词库统计:"
echo "   白霜核心词库: $(ls "$DEST"/frost.*.dict.yaml 2>/dev/null | wc -l) 个文件"
echo "   白霜细胞词库: $(ls "$DEST"/frost_cell.*.dict.yaml 2>/dev/null | wc -l) 个文件"
echo "   雾凇补充词库: $(ls "$DEST"/rime_ice.*.dict.yaml 2>/dev/null | wc -l) 个文件"
echo "   自定义词库:   $(ls "$DEST"/rome_*.dict.yaml 2>/dev/null | wc -l) 个文件"
echo "   其他词库:     $(ls "$DEST"/other_*.dict.yaml 2>/dev/null | wc -l) 个文件"
echo ""
echo "💡 后续更新: 词库将由 GitHub Actions 每周自动同步"
echo "   也可手动触发: GitHub → Actions → Sync Upstream Dicts → Run workflow"
