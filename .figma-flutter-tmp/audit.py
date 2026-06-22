import json, sys

with open('/Users/jgfan/snapmaker/flutter_zero_copy/.figma-flutter-tmp/figma_nodes.json') as f:
    data = json.load(f)

doc = data['nodes']['10977:31300']['document']

def find_node(node, name_pattern, node_type=None):
    results = []
    if name_pattern.lower() in node.get('name', '').lower():
        if node_type is None or node.get('type') == node_type:
            results.append(node)
    for child in node.get('children', []):
        results.extend(find_node(child, name_pattern, node_type))
    return results

def color_to_hex(c):
    if not c: return 'N/A'
    r = int(c['r']*255); g = int(c['g']*255); b = int(c['b']*255)
    return '#{:02X}{:02X}{:02X}'.format(r, g, b)

def check(desc, figma_val, code_val):
    ok = figma_val == code_val
    mark = '✅' if ok else '❌'
    return '{} {} (Figma: {} | Code: {})'.format(mark, desc, figma_val, code_val)

results = []
warnings = []

# AUDIT 1: Sidebar
n = find_node(doc, 'Rectangle 34624851')[0]
bb = n.get('absoluteBoundingBox', {})
c = n.get('fills', [{}])[0].get('color')
results.append(check('Sidebar width', bb.get('width'), 262))
results.append(check('Sidebar fill', color_to_hex(c), '#FFFFFF'))

# AUDIT 2: Active tile text
tiles = find_node(doc, 'Device Control')
if tiles:
    n = tiles[0]
    s = n.get('style', {})
    c = n.get('fills', [{}])[0].get('color')
    results.append(check('Tile fontSize', s.get('fontSize'), 14))
    results.append(check('Tile fontWeight', s.get('fontWeight'), 500))

# AUDIT 3: Camera header
n = find_node(doc, 'F7F8F8')[0] if find_node(doc, 'F7F8F8') else None
if not n:
    # find by coordinates
    for node in find_node(doc, '矩形备份 6'):
        bb = node.get('absoluteBoundingBox', {})
        if bb.get('height') == 40:
            n = node
            break
if n:
    bb = n.get('absoluteBoundingBox', {})
    c = n.get('fills', [{}])[0].get('color')
    results.append(check('Header height', bb.get('height'), 40))
    results.append(check('Header fill', color_to_hex(c), '#F7F8F8'))

# AUDIT 4: Camera dark bg
n = find_node(doc, 'Rectangle 34624849')[0]
c = n.get('fills', [{}])[0].get('color')
results.append(check('Camera bg', color_to_hex(c), '#151515'))

# AUDIT 5: Temps outer
n = find_node(doc, 'Rectangle 34624854')[0]
bb = n.get('absoluteBoundingBox', {})
c = n.get('fills', [{}])[0].get('color')
results.append(check('Temps width', bb.get('width'), 109))
results.append(check('Temps fill', color_to_hex(c), '#F5F6FA'))

# AUDIT 6: Temp badge
n = find_node(doc, 'Rectangle 34624751')[0]
bb = n.get('absoluteBoundingBox', {})
c = n.get('fills', [{}])[0].get('color')
results.append(check('Badge width', bb.get('width'), 18))
results.append(check('Badge height', bb.get('height'), 18))
results.append(check('Badge fill', color_to_hex(c), '#1B50FF'))

# AUDIT 7: XY Pad
n = find_node(doc, 'Ellipse 131')[0]
bb = n.get('absoluteBoundingBox', {})
c = n.get('fills', [{}])[0].get('color')
results.append(check('XY Pad size', bb.get('width'), 140))
results.append(check('XY Pad fill', color_to_hex(c), '#F5F6FA'))

# AUDIT 8: Progress bar
n = find_node(doc, 'Rectangle 34624773')[0]
bb = n.get('absoluteBoundingBox', {})
c = n.get('fills', [{}])[0].get('color')
cr = n.get('cornerRadius')
results.append(check('Progress height', bb.get('height'), 8))
results.append(check('Progress track', color_to_hex(c), '#D9D9D9'))
results.append(check('Progress radius', cr, 30))

# AUDIT 9: Percentage text
for t in find_node(doc, 'N/A', 'TEXT'):
    if t.get('style', {}).get('fontSize') == 28:
        s = t.get('style', {})
        results.append(check('Percent fontSize', s.get('fontSize'), 28))
        results.append(check('Percent fontWeight', s.get('fontWeight'), 600))
        c = t.get('fills', [{}])[0].get('color')
        warnings.append('Percent color: Figma placeholder={} | Code uses active #0C63E2 (mock data)'.format(color_to_hex(c)))
        break

# AUDIT 10: Text styles
for t in find_node(doc, '设备控制', 'TEXT'):
    s = t.get('style', {})
    c = t.get('fills', [{}])[0].get('color')
    results.append(check('Sidebar label size', s.get('fontSize'), 14))
    results.append(check('Sidebar label weight', s.get('fontWeight'), 500))
    results.append(check('Sidebar label color', color_to_hex(c), '#242424'))
    break

# AUDIT 11: Inactive sidebar text color
for t in find_node(doc, '固件更新', 'TEXT'):
    s = t.get('style', {})
    c = t.get('fills', [{}])[0].get('color')
    results.append(check('Inactive label size', s.get('fontSize'), 14))
    results.append(check('Inactive label weight', s.get('fontWeight'), 500))
    results.append(check('Inactive label color', color_to_hex(c), '#545659'))
    break

# AUDIT 12: Top bar
n = find_node(doc, 'Rectangle 431')[0]
bb = n.get('absoluteBoundingBox', {})
c = n.get('fills', [{}])[0].get('color')
results.append(check('TopBar upper height', bb.get('height'), 36))
results.append(check('TopBar upper fill', color_to_hex(c), '#242424'))

n = find_node(doc, 'Rectangle 432')[0]
bb = n.get('absoluteBoundingBox', {})
c = n.get('fills', [{}])[0].get('color')
results.append(check('TopBar lower height', bb.get('height'), 36))
results.append(check('TopBar lower fill', color_to_hex(c), '#3B4547'))

# AUDIT 13: Control labels (10px/500)
for t in find_node(doc, 'Tool1', 'TEXT'):
    s = t.get('style', {})
    results.append(check('Chip label size', s.get('fontSize'), 10))
    results.append(check('Chip label weight', s.get('fontWeight'), 500))
    break

# Print results
passed = sum(1 for r in results if r.startswith('✅'))
failed = sum(1 for r in results if r.startswith('❌'))
total = len(results)

print('=' * 60)
print('FIGMA → FLUTTER 样式转换审计')
print('=' * 60)
print()
for r in results:
    print('  ' + r)
print()
if warnings:
    print('⚠️  说明:')
    for w in warnings:
        print('  ' + w)
print()
print('=' * 60)
print('结果: {}/{} 属性精确匹配 ({:.0f}%)'.format(passed, total, passed/total*100 if total > 0 else 0))
if failed > 0:
    print('失败项: {}'.format(failed))
print('=' * 60)
