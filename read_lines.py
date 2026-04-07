f = r'c:\1.0_ejdida_1_3_4\mobile\lib\screens\home_screen.dart'
with open(f, 'r', encoding='utf-8', errors='replace') as fp:
    lines = fp.readlines()
for i in range(184, 193):
    print(repr(f'{i+1}: {lines[i]}'))
