with open('sha.txt', 'r', encoding='utf-16') as f:
    for line in f:
        if 'SHA1:' in line:
            print(line.strip())
