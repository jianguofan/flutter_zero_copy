#!/bin/bash
# 文档同步检查脚本
# 用途: 检查架构文档中声明的类是否在代码中存在

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "🔍 检查文档与代码同步性..."
echo ""

VIOLATIONS=0

# ============================================================
# ARCH-01: 文档声明的类必须存在
# ============================================================
echo "📋 [ARCH-01] 检查文档声明的类是否存在..."

DOC_FILE="docs/architecture/DEVICE_ARCHITECTURE.md"

if [ ! -f "$DOC_FILE" ]; then
  echo "⚠️  架构文档不存在: $DOC_FILE"
  exit 1
fi

# 提取文档中提到的关键类
DECLARED_CLASSES=(
  "DeviceMetadataStore"
  "DeviceSessionImpl"
  "DeviceImpl"
  "DeviceRegistryImpl"
  "LavaSdkConnection"
  "DeviceManagerService"
)

echo "检查以下核心类:"
for class in "${DECLARED_CLASSES[@]}"; do
  echo -n "  - $class ... "
  if grep -rq "class $class" lib/; then
    echo "✅"
  else
    echo "❌ 不存在"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done

echo ""

# ============================================================
# 检查文档中声明的 Providers
# ============================================================
echo "📋 检查文档中声明的 Providers..."

DECLARED_PROVIDERS=(
  "deviceSessionProvider"
  "deviceSessionStateProvider"
  "activeDeviceProvider"
  "deviceRegistryProvider"
  "deviceListProvider"
  "deviceFieldStreamProvider"
  "deviceFieldValueProvider"
  "sendDeviceCommandProvider"
)

echo "检查以下核心 Providers:"
for provider in "${DECLARED_PROVIDERS[@]}"; do
  echo -n "  - $provider ... "
  if grep -rq "final $provider" lib/; then
    echo "✅"
  else
    echo "❌ 不存在"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done

echo ""

# ============================================================
# 检查是否有新增 Provider 但未更新文档
# ============================================================
echo "📋 检查是否有新增 Provider 未记录..."

ACTUAL_PROVIDERS=$(grep -rh "final.*Provider\s*=" lib/features/*/application/providers/ 2>/dev/null | \
  grep -oE "\w+Provider" | sort -u || true)

if [ -n "$ACTUAL_PROVIDERS" ]; then
  echo "代码中的 Providers:"
  while IFS= read -r provider; do
    if grep -q "$provider" "$DOC_FILE"; then
      echo "  ✅ $provider (已记录)"
    else
      echo "  ⚠️  $provider (未在文档中记录)"
      VIOLATIONS=$((VIOLATIONS + 1))
    fi
  done <<< "$ACTUAL_PROVIDERS"
fi

echo ""

# ============================================================
# 总结
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $VIOLATIONS -eq 0 ]; then
  echo "✅ 文档同步检查通过！"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
else
  echo "❌ 发现 $VIOLATIONS 处不同步"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "请更新 $DOC_FILE 或实现缺失的类/Provider"
  exit 1
fi
