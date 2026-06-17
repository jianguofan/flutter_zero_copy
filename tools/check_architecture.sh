#!/bin/bash
# 架构规则自动化检查脚本
# 版本: 1.0
# 用途: CI/CD 中自动检查架构规则违规

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "🔍 开始架构规则检查..."
echo "项目根目录: $PROJECT_ROOT"
echo ""

VIOLATIONS=0

# ============================================================
# LAYER-01: UI 层不得直接导入 SDK
# ============================================================
echo "📋 [LAYER-01] 检查 UI 层是否直接导入 SDK..."

UI_PATHS="lib/pages lib/widgets"
SDK_IMPORT="lava_device_sdk"

for path in $UI_PATHS; do
  if [ -d "$path" ]; then
    RESULTS=$(grep -r "import.*$SDK_IMPORT" "$path" 2>/dev/null || true)
    if [ -n "$RESULTS" ]; then
      echo "❌ LAYER-01 违规: UI 层直接导入 SDK"
      echo "$RESULTS"
      VIOLATIONS=$((VIOLATIONS + 1))
    fi
  fi
done

if [ $VIOLATIONS -eq 0 ]; then
  echo "✅ LAYER-01 通过"
fi
echo ""

# ============================================================
# LAYER-03: Provider 不得导入 Flutter UI 框架
# ============================================================
echo "📋 [LAYER-03] 检查 Provider 是否导入 Flutter UI..."

PROVIDER_PATHS=$(find lib/features -type d -path "*/application/providers" 2>/dev/null || true)
FLUTTER_IMPORTS="flutter/material|flutter/widgets"

if [ -n "$PROVIDER_PATHS" ]; then
  for path in $PROVIDER_PATHS; do
    RESULTS=$(grep -rE "import.*(package:)?(flutter/material|flutter/widgets)" "$path" 2>/dev/null || true)
    if [ -n "$RESULTS" ]; then
      echo "❌ LAYER-03 违规: Provider 导入了 Flutter UI"
      echo "$RESULTS"
      VIOLATIONS=$((VIOLATIONS + 1))
    fi
  done
fi

if [ $VIOLATIONS -eq 0 ]; then
  echo "✅ LAYER-03 通过"
fi
echo ""

# ============================================================
# LAYER-04: 数据层不得导入 Riverpod
# ============================================================
echo "📋 [LAYER-04] 检查数据层是否导入 Riverpod..."

DATA_PATHS=$(find lib/features -type d -path "*/data" 2>/dev/null || true)

if [ -n "$DATA_PATHS" ]; then
  for path in $DATA_PATHS; do
    RESULTS=$(grep -r "import.*flutter_riverpod" "$path" 2>/dev/null || true)
    if [ -n "$RESULTS" ]; then
      echo "❌ LAYER-04 违规: 数据层导入了 Riverpod"
      echo "$RESULTS"
      VIOLATIONS=$((VIOLATIONS + 1))
    fi
  done
fi

if [ $VIOLATIONS -eq 0 ]; then
  echo "✅ LAYER-04 通过"
fi
echo ""

# ============================================================
# SUB-01: Timer 必须在 dispose 中取消
# ============================================================
echo "📋 [SUB-01] 检查 Timer 是否正确取消..."

TIMER_FILES=$(grep -rl "Timer\.periodic" lib/ 2>/dev/null || true)

if [ -n "$TIMER_FILES" ]; then
  for file in $TIMER_FILES; do
    if ! grep -q "\.cancel()" "$file"; then
      echo "⚠️  SUB-01 警告: $file 中 Timer.periodic 可能未取消"
      echo "   请检查 dispose() 方法中是否调用 timer?.cancel()"
      VIOLATIONS=$((VIOLATIONS + 1))
    fi
  done
fi

if [ $VIOLATIONS -eq 0 ]; then
  echo "✅ SUB-01 通过"
fi
echo ""

# ============================================================
# SUB-02: addListener 必须配对 removeListener
# ============================================================
echo "📋 [SUB-02] 检查 addListener/removeListener 配对..."

ADD_LISTENER_FILES=$(grep -rl "\.addListener(" lib/ 2>/dev/null || true)

if [ -n "$ADD_LISTENER_FILES" ]; then
  for file in $ADD_LISTENER_FILES; do
    ADD_COUNT=$(grep -c "\.addListener(" "$file" || true)
    REMOVE_COUNT=$(grep -c "\.removeListener(" "$file" || true)

    if [ "$ADD_COUNT" -ne "$REMOVE_COUNT" ]; then
      echo "⚠️  SUB-02 警告: $file"
      echo "   addListener: $ADD_COUNT 次, removeListener: $REMOVE_COUNT 次"
      echo "   请确保每个 addListener 都有对应的 removeListener"
      VIOLATIONS=$((VIOLATIONS + 1))
    fi
  done
fi

if [ $VIOLATIONS -eq 0 ]; then
  echo "✅ SUB-02 通过"
fi
echo ""

# ============================================================
# SUB-03: StreamSubscription 必须取消
# ============================================================
echo "📋 [SUB-03] 检查 StreamSubscription 是否取消..."

SUBSCRIPTION_FILES=$(grep -rl "StreamSubscription" lib/ 2>/dev/null || true)

if [ -n "$SUBSCRIPTION_FILES" ]; then
  for file in $SUBSCRIPTION_FILES; do
    if grep -q "StreamSubscription.*=" "$file" && ! grep -q "\.cancel()" "$file"; then
      echo "⚠️  SUB-03 警告: $file"
      echo "   发现 StreamSubscription 但未找到 cancel() 调用"
      VIOLATIONS=$((VIOLATIONS + 1))
    fi
  done
fi

if [ $VIOLATIONS -eq 0 ]; then
  echo "✅ SUB-03 通过"
fi
echo ""

# ============================================================
# PROV-01: Provider 命名约定
# ============================================================
echo "📋 [PROV-01] 检查 Provider 命名约定..."

PROVIDER_FILES=$(find lib -name "*provider*.dart" -type f 2>/dev/null || true)

if [ -n "$PROVIDER_FILES" ]; then
  for file in $PROVIDER_FILES; do
    # 检查 Provider 定义是否以 Provider 结尾
    BAD_NAMES=$(grep -E "^(final|var|const)\s+\w+" "$file" | grep -E "Provider\s*=" | grep -vE "\w+Provider\s*=" || true)
    if [ -n "$BAD_NAMES" ]; then
      echo "⚠️  PROV-01 警告: $file"
      echo "   Provider 变量名应以 'Provider' 结尾"
      echo "$BAD_NAMES"
      VIOLATIONS=$((VIOLATIONS + 1))
    fi
  done
fi

if [ $VIOLATIONS -eq 0 ]; then
  echo "✅ PROV-01 通过"
fi
echo ""

# ============================================================
# 总结
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $VIOLATIONS -eq 0 ]; then
  echo "✅ 所有架构规则检查通过！"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
else
  echo "❌ 发现 $VIOLATIONS 处潜在违规"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "请参考 docs/architecture/CODE_REVIEW_RULES.md"
  exit 1
fi
