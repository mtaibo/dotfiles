# fixcontent.py <content.xml in> <out> <missing filename>...  : drops dataFiles items and filesToEnable lines for missing files
import re,sys
s=open(sys.argv[1],encoding='utf-8-sig').read()
for f in sys.argv[3:]:
    e=re.escape(f)
    s,n1=re.subn(r'\s*<Item>\s*<filename>'+e+r'</filename>.*?</Item>','',s,flags=re.S)
    s,n2=re.subn(r'\s*<Item>'+e+r'</Item>','',s)
    print(f,'removed',n1,n2)
open(sys.argv[2],'w',encoding='utf-8').write(s)
