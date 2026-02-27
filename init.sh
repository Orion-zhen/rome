#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 初始化脚本 (init.sh)
# 功能：
# 1. 自动同步白霜拼音与雾凇拼音词库 (融合 scripts/init-dicts.sh)
# 2. 自动下载 Octagram 语言模型 (二元+三元)
# 3. 自动配置 rome.schema.yaml 使用更高级的三元模型
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
TEMP_DIR=$(mktemp -d)
DICT_DEST="$REPO_ROOT/dicts"

echo "🚀 开始初始化 Rome 输入法配置..."
echo "📂 项目根目录: $REPO_ROOT"
echo "📂 词库目录: $DICT_DEST"
echo "📂 临时缓存: $TEMP_DIR"
echo ""

# =======================================================
# 第一部分：词库同步 (逻辑源自 scripts/init-dicts.sh)
# =======================================================

# 1. 克隆白霜拼音
echo "❄️  [1/4] 正在拉取白霜拼音 (rime-frost)..."
git clone --depth 1 https://github.com/gaboolic/rime-frost.git "$TEMP_DIR/rime-frost"

echo "   → 同步核心词库..."
mkdir -p "$DICT_DEST"
cp "$TEMP_DIR/rime-frost/cn_dicts/8105.dict.yaml"  "$DICT_DEST/frost.8105.dict.yaml"
cp "$TEMP_DIR/rime-frost/cn_dicts/41448.dict.yaml" "$DICT_DEST/frost.41448.dict.yaml"
cp "$TEMP_DIR/rime-frost/cn_dicts/base.dict.yaml"  "$DICT_DEST/frost.base.dict.yaml"
cp "$TEMP_DIR/rime-frost/cn_dicts/ext.dict.yaml"   "$DICT_DEST/frost.ext.dict.yaml"

echo "   → 同步细胞词库..."
for file in "$TEMP_DIR/rime-frost/cn_dicts_cell"/*.dict.yaml; do
  filename=$(basename "$file")
  cp "$file" "$DICT_DEST/frost_cell.${filename}"
done

# 2. 克隆雾凇拼音
echo ""
echo "🧊 [2/4] 正在拉取雾凇拼音 (rime-ice)..."
git clone --depth 1 https://github.com/iDvel/rime-ice.git "$TEMP_DIR/rime-ice"

echo "   → 同步腾讯词库和杂项..."
cp "$TEMP_DIR/rime-ice/cn_dicts/tencent.dict.yaml" "$DICT_DEST/rime_ice.tencent.dict.yaml"
cp "$TEMP_DIR/rime-ice/cn_dicts/others.dict.yaml"  "$DICT_DEST/rime_ice.others.dict.yaml"

echo "   → 同步英文词库..."
cp "$TEMP_DIR/rime-ice/en_dicts/en.dict.yaml"     "$DICT_DEST/rime_ice.en.dict.yaml"
cp "$TEMP_DIR/rime-ice/en_dicts/en_ext.dict.yaml" "$DICT_DEST/rime_ice.en_ext.dict.yaml"

echo "   → 同步 OpenCC 数据..."
mkdir -p $REPO_ROOT/opencc
cp -r "$TEMP_DIR/rime-ice/opencc"/* "$REPO_ROOT/opencc/" 2>/dev/null || true

echo "   → 同步中英混输词库..."
[ -f "$TEMP_DIR/rime-ice/cn_dicts/cn_en.txt" ] && cp "$TEMP_DIR/rime-ice/cn_dicts/cn_en.txt" "$DICT_DEST/rime_ice.cn_en.txt" || true

# 3. 清理旧文件
echo ""
echo "🧹 [3/4] 清理旧的词库文件..."
rm -f "$DICT_DEST/rime_ice.8105.dict.yaml"
rm -f "$DICT_DEST/rime_ice.41448.dict.yaml"
rm -f "$DICT_DEST/rime_ice.base.dict.yaml"
rm -f "$DICT_DEST/rime_ice.ext.dict.yaml"

# =======================================================
# 第二部分：下载 Octagram 语言模型
# =======================================================
echo ""
echo "🧠 [4/4] 配置 Octagram 语言模型..."
MODEL_URL_BASE="https://raw.githubusercontent.com/lotem/rime-octagram-data/hans"
# 下载二元 (bgw) 和三元 (tgw) 模型
for model in "zh-hans-t-essay-bgw.gram" "zh-hans-t-essay-tgw.gram"; do
    if [ ! -f "$REPO_ROOT/$model" ]; then
        echo "   ⬇️  正在下载 $model (可能需要一些时间)..."
        if curl -L -o "$REPO_ROOT/$model" "$MODEL_URL_BASE/$model"; then
            echo "   ✅ 下载成功: $model"
        else
            echo "   ❌ 下载失败: $model"
            echo "      请检查网络连接或手动下载至项目根目录。"
        fi
    else
        echo "   ✅ 已存在: $model (跳过下载)"
    fi
done

# =======================================================
# 第三部分：自动更新方案配置
# =======================================================
echo ""
echo "⚙️  检查方案配置..."
SCHEMA_FILE="$REPO_ROOT/rome.schema.yaml"
if [ -f "$SCHEMA_FILE" ]; then
    # 如果当前配置是二元模型 (bgw)，自动升级为三元 (tgw)
    if grep -q "zh-hans-t-essay-bgw" "$SCHEMA_FILE"; then
        echo "   🆙 检测到二元模型配置，正在升级为三元模型 (tgw)..."
        # 使用兼容 Linux/macOS 的 sed 语法
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' 's/zh-hans-t-essay-bgw/zh-hans-t-essay-tgw/g' "$SCHEMA_FILE"
        else
            sed -i 's/zh-hans-t-essay-bgw/zh-hans-t-essay-tgw/g' "$SCHEMA_FILE"
        fi
        echo "   ✅ 更新完成：rome.schema.yaml"
    elif grep -q "zh-hans-t-essay-tgw" "$SCHEMA_FILE"; then
        echo "   ✅ 当前已配置为三元模型 (tgw)"
    else
        echo "   ℹ️  未找到 Octagram 默认配置，可能已被手动修改，跳过自动更新。"
    fi
fi

# 清理临时目录
rm -rf "$TEMP_DIR"

echo ""
echo "🎉 所有初始化步骤已完成！"
echo "   请重新部署 Rime 以使更改生效。"
