unit USeamCarving;

interface

uses Windows,Types, Graphics, Math,StrUtils, SysUtils;

procedure SeamCarving(const bm_in: TBitmap;const bm_out: TBitmap;
                GaussSize:integer;GaussTheta:single;
                CropWidth,CropHeight:integer;
                step:integer);

implementation

type
 TLongArray = array[0..65535] of integer;
 PLongArray = ^TLongArray;
 TIntArray = array[0..65535] of integer;


var
 Pbm_In, Pbm_Out: PLongArray;
 Gray_In:array of integer;     // image originale en gris
 Work_In:array of integer;     // image en cours
 Tmp_In:array of integer;      // image temporaire entre H et V
 seamsFinded:array of integer; // liste des chemins trouvés
 seamsFindedCount:integer;
 Energy:array of integer;      // gradient par le filtre de sobel
 Map:array of integer;         // carte pour le chemin le moins couteux

 SeamsPath:array of integer;   // chemin courant dans l'image
 Width,Height:integer;         // dimension de l'image actuelle

 Ori_Width,Ori_Height:integer; // dimension d'origine (dans les tableaux)






// fonctions diverses...
//==============================================================================

function RGBA(r, g, b, a: Byte): COLORREF;
begin
  Result := (r or (g shl 8) or (b shl 16) or (a shl 24));
end;

function ArcEnCiel(a:integer):integer;
begin
  while a<0 do a:=a+360;
  Case (a div 60) mod 6 of
      0: result:=RGB(255 ,17*(a Mod 60) shr 2,  0);
      1: result:=RGB(255-17*(a Mod 60) shr 2 ,255 ,  0);
      2: result:=RGB(  0 ,255 ,17*(a Mod 60) shr 2);
      3: result:=RGB(  0 ,255-17*(a Mod 60) shr 2 ,255);
      4: result:=RGB(17*(a Mod 60) shr 2,  0 ,255);
      5: result:=RGB(255 ,  0 ,255-17*(a Mod 60) shr 2);
   end;
end;


function RGBtoGray(c:longint):longint;
var
 r,g,b:cardinal;
begin
  r := (c and $FF0000)   shr 16;
  g := (c and $00FF00) shr  8;
  b := (c and $0000FF) ;

  c:=(r*77+g*151+b*28) shr 8;
  result :=c;
end;

//==============================================================================

function getPixel(pt:pointer;xx,yy:integer):longint;
begin
 result:= PLongArray(pt)[xx+yy*Ori_Width];
end;

procedure SetPixel(pt:pointer;xx,yy,px:integer);
begin
 PLongArray(pt)[xx+yy*Ori_Width]:=px;
end;

procedure copyimage(pt_In,pt_Out:pointer);
var
 i,j:integer;
begin
 for j:=0 to Ori_Height-1 do for i:=0 to Ori_Width-1 do
      SetPixel(pt_Out,i,j,GetPixel(pt_In,i,j));
end;


// passe l'image en niveau de gris
//==============================================================================
procedure MakeGrayScale(CopyFrom:pointer);
var
 i,j:integer;
 c:integer;
begin
 for j:=0 to Height-1 do
  for i:=0 to Width-1 do
   SetPixel(Gray_In,i,j,RGBtoGray(GetPixel(CopyFrom,i,j)));
end;


// applique un flou gaussien
//==============================================================================

procedure GaussianBlur(size:integer;theta:single);
var
 i,j,x,y:integer;
 col:single;
 c:dword;
 theta2:single;
 GaussSum:single;
 GaussMatrice:array of array of single;
begin
 // si la taille est 1, il n'y a pas de flou...
 if size=1 then
  begin
   for j:=0 to Height-1 do for i:=0 to Width-1 do
     SetPixel(Work_In,i,j,getPixel(Gray_In,i,j));
   exit;
  end;

 // calcul la matrice pour le filtre
 theta2:=2*theta*theta;
 size:=size-1;
 setlength(GaussMatrice,size*2+1);
 GaussSum:=0;
 for j:=-size to size do
  begin
    setlength(GaussMatrice[size+j],size*2+1);
    for i:=0 to size-1 do
     begin
      GaussMatrice[size+j,size+i]:=exp(-(j*j+i*i)/theta2)/(pi*theta2);
      GaussSum:=GaussSum+GaussMatrice[size+j,size+i];
      if i=0 then continue;
      GaussMatrice[size+j,size-i]:=GaussMatrice[size+j,size+i];
      GaussSum:=GaussSum+GaussMatrice[size+j,size+i];
     end;
  end;

 // on applique la matrice
 for j:=0 to Height-1 do
  for i:=0 to Width-1 do
   begin
    col:=0;
    for y:=-size to size do for x:=-size to size do
     begin
      if (i+x>=0) and (j+y>=0) and (i+x<Width) and (j+y<Height) then
       col:=col+GaussMatrice[size+x,size+y]*getPixel(Gray_In,i+x,j+y);
     end;
    SetPixel(Work_In,i,j,round(col/GaussSum));
   end;
end;

// applique le filtre de Sobel qui recherche les contours suivant X et Y
//==============================================================================

const
 Matrice_Sobel_x:array[-1..1,-1..1] of integer=((-1,0,1),  (-2,0,2),  (-1,0,1));
 Matrice_Sobel_y:array[-1..1,-1..1] of integer=((1,2,1),  (0,0,0),  (-1,-2,-1));

procedure Sobelxy(EnergyTab:pointer;x,y:integer);
var
 i,j,i1,i2,j1,j2:integer;
 colx,coly:integer;
 c:dword;
 e:extended;
begin
 colx:=0;
 coly:=0;
 if x=0 then i1:=0 else i1:=-1;
 if x=Width-1 then i2:=0 else i2:=1;

 if y=0 then j1:=0 else j1:=-1;
 if y=Height-1 then j2:=0 else j2:=1;

 for j:=j1 to j2 do for i:=i1 to i2 do
  begin
   c:=getPixel(Work_In,i+x,j+y);
   colx:=colx+Matrice_Sobel_x[i,j]*c;
   coly:=coly+Matrice_Sobel_y[i,j]*c;
  end;
 e:=sqrt(colx*colx+coly*coly);
 SetPixel(EnergyTab,x,y,round(e));
end;

procedure Sobel;
var
 i,j,x,y:integer;
begin
 for j:=0 to Height-1 do
  for i:=0 to Width-1 do
   Sobelxy(Energy,i,j);
end;


//==============================================================================
//==============================================================================
procedure MakeSeamsPathV(n:integer);
var
 jj:integer;
 ee1,ee2,ee3:integer;
begin
 SeamsPath[height-1]:=n;
 for jj := height-1 downto 1 do
  begin
   SeamsPath[jj]:=n;
   if n>0 then ee1:=GetPixel(Map,n-1,jj-1) else ee1:=$FFFFFF;
   ee2:=GetPixel(Map,n,jj-1);
   if n<width-1 then ee3:=GetPixel(Map,n+1,jj-1) else ee3:=$FFFFFF;
   if (ee1<ee2) and (ee1<ee3) then n:=n-1
   else
   if (ee3<ee1) and (ee3<ee2) then n:=n+1;
  end;
 SeamsPath[0]:=n;
end;

procedure FindSeamsV;
var
 i,j,e,e1,e2,e3,m: Integer;
begin
 for i := 0 to Width-1 do SetPixel(Map,i,0,GetPixel(Energy,i,0));

 for j:= 1 to height - 1 do
  for i := 0 to Width - 1 do
   begin
    e:=GetPixel(Energy,i,j);
    if i>0 then e1:=GetPixel(Map,i-1,j-1) else e1:=$FFFFFF;
    e2:=GetPixel(Map,i,j-1);
    if i<width-1 then e3:=GetPixel(Map,i+1,j-1) else e3:=$FFFFFF;
    e:=e+min(e1,min(e2,e3));
    SetPixel(Map,i,j,e);
   end;


 m:=GetPixel(Map,0,height-1);
 j:=0;
 for i := 1 to Width-1 do
  begin
   e:=GetPixel(Map,i,height-1);
   if m>e then
    begin
     m:=e;
     j:=i;
    end;
  end;

 MakeSeamsPathV(j);
end;


//==============================================================================
//==============================================================================

procedure MakeSeamsPathH(nn:integer);
var
 ii:integer;
 ee1,ee2,ee3:integer;
begin
 for ii := Width-1 downto 1 do
  begin
   SeamsPath[ii]:=nn;
   if nn>0 then        ee1:=GetPixel(Map,ii-1,nn-1) else ee1:=$FFFFFF;
                       ee2:=GetPixel(Map,ii-1,nn);
   if nn<Height-1 then ee3:=GetPixel(Map,ii-1,nn+1) else ee3:=$FFFFFF;
   if (ee1<ee2) and (ee1<ee3) then nn:=nn-1
   else
   if (ee3<ee2) then nn:=nn+1;
  end;
 SeamsPath[0]:=nn;
end;

procedure FindSeamsH;
var
 i,j,e,e1,e2,e3,m: Integer;
begin
 for j := 0 to Height-1 do SetPixel(Map,0,j,GetPixel(Energy,0,j));

 for i := 1 to Width - 1 do
 for j:= 0 to Height - 1 do
   begin
    e:=GetPixel(Energy,i,j);
    if j>0 then e1:=GetPixel(Map,i-1,j-1) else e1:=$FFFFFF;
    e2:=GetPixel(Map,i-1,j);
    if j<Height-1 then e3:=GetPixel(Map,i-1,j+1) else e3:=$FFFFFF;
    e:=e+min(e1,min(e2,e3));
    SetPixel(Map,i,j,e);
   end;


 m:=GetPixel(Map,Width-1,0);
 i:=0;
 for j := 1 to height-1 do
  begin
   e:=GetPixel(Map,Width-1,j);
   if m>e then
    begin
     m:=e;
     i:=j;
    end;
  end;

 MakeSeamsPathH(i);
end;

//==============================================================================
//==============================================================================


procedure updateSeamMapH;
var
 i,j,accu:integer;
begin
 inc(seamsFindedCount);
 for i := 0 to Ori_Width - 1 do
  begin
   accu:=0;
   for j:= 0 to Ori_Height - 1 do
    begin
     if GetPixel(seamsFinded,i,j)=0 then
      begin
       if accu=SeamsPath[i] then
        begin
         SetPixel(seamsFinded,i,j,seamsFindedCount);
         break;
        end
       else
        inc(accu);
      end;
    end;
  end;
end;

procedure updateSeamMapV;
var
 i,j,accu:integer;
begin
 inc(seamsFindedCount);
 for j:= 0 to Ori_Height - 1 do
  begin
   accu:=0;
   for i:= 0 to Ori_Width - 1 do
    begin
     if GetPixel(seamsFinded,i,j)=0 then
      begin
       if accu=SeamsPath[j] then
        begin
         SetPixel(seamsFinded,i,j,seamsFindedCount);
         break;
        end
       else
        inc(accu);
      end;
    end;
  end;
end;


//==============================================================================
//==============================================================================

procedure CompressH;
var
 i,j:integer;
begin
 for i := 0 to Width - 1 do
    for j := SeamsPath[i]+1 to Height-1 do SetPixel(Work_In,i,j-1,getpixel(Work_In,i,j));
end;

procedure CompressV;
var
 i,j:integer;
begin
 for j := 0 to Height - 1 do
    for i := SeamsPath[j]+1 to Width-1 do SetPixel(Work_In,i-1,j,getpixel(Work_In,i,j));
end;

//==============================================================================
//==============================================================================

procedure UpdateEnergyH;
var
 i,j,x,y:integer;
begin
 for i := 0 to Width - 1 do
   for j := SeamsPath[i]+1 to Height-1 do SetPixel(Energy,i,j-1,getpixel(Energy,i,j));

 //recalcul les energies au niveau du chemin
  for i := 0 to Width - 1 do
    begin
     j:=SeamsPath[i];
     for x:=-1 to 1 do
      for y:=-1 to 0 do
        if (i+x>=0) and (j+y>=0) and (i+x<Width) and (j+y<Height-1) then sobelxy(Energy,i+x,j+y);
    end;
end;

procedure UpdateEnergyV;
var
 i,j,x,y:integer;
begin
 for j := 0 to Height - 1 do
   for i := SeamsPath[j]+1 to Width-1 do SetPixel(Energy,i-1,j,getpixel(Energy,i,j));

 //recalcul les energies au niveau du chemin
  for j := 0 to Height - 1 do
    begin
     i:=SeamsPath[j];
     for x:=-1 to 0 do
      for y:=-1 to 1 do
        if (i+x>=0) and (j+y>=0) and (i+x<Width-1) and (j+y<Height) then sobelxy(Energy,i+x,j+y);
    end;
end;

//==============================================================================
//==============================================================================

procedure reduceimageH(Copyfrom,copyTo:pointer);
var
 i,j,y:integer;
begin
 for i := 0 to Ori_Width - 1 do
  begin
   y:=0;
   for j := 0 to Ori_Height - 1 do
     if getpixel(seamsFinded,i,j)=0 then
      begin
       SetPixel(copyTo,i,y,getpixel(Copyfrom,i,j));
       inc(y);
      end;
  end;
end;

//==============================================================================
//==============================================================================

procedure reduceimageV(Copyfrom,copyTo:pointer);
var
 i,j,x:integer;
begin
 for j := 0 to Ori_Height - 1 do
  begin
   x:=0;
   for i := 0 to Ori_Width - 1 do
     if getpixel(seamsFinded,i,j)=0 then
      begin
       SetPixel(copyTo,x,j,getpixel(Copyfrom,i,j));
       inc(x);
      end;
  end;
end;

//==============================================================================
//==============================================================================

procedure ShowSeams(OriginalPict:boolean);
var
 i,j:integer;
begin
 if OriginalPict then
  begin
   for i:=0 to Ori_Width-1 do for j:=0 to Ori_Height-1 do
    if GetPixel(seamsFinded,i,j)=0 then SetPixel(Pbm_Out,i,j,GetPixel(Tmp_In,i,j))
      else SetPixel(Pbm_Out,i,j,$FF0000);
  end
 else
  begin
   for i:=0 to Ori_Width-1 do for j:=0 to Ori_Height-1 do
    if GetPixel(seamsFinded,i,j)=0 then SetPixel(Pbm_Out,i,j,0)
      else SetPixel(Pbm_Out,i,j,arcenciel(GetPixel(seamsFinded,i,j)));
  end;
end;

//==============================================================================
//==============================================================================

procedure ShowBuff(buff:pointer);
var
 i,j:integer;
begin
  for i:=0 to Ori_Width-1 do for j:=0 to Ori_Height-1 do
   SetPixel(Pbm_Out,i,j,GetPixel(buff,i,j));
end;

//==============================================================================
//==============================================================================
procedure ClearBuff;
begin
 setlength(Gray_In,0);
 setlength(Work_In,0);
 setlength(Tmp_In,0);
 setlength(seamsFinded,0);
 setlength(Energy,0);
 setlength(Map,0);
end;

procedure SeamCarving(const bm_in: TBitmap;const bm_out: TBitmap;
                GaussSize:integer;GaussTheta:single;
                CropWidth,CropHeight:integer;
                Step:integer);
var
 i,j:integer;
begin
 // initialisation des variables
 Width :=bm_In.Width;
 Height:=bm_In.Height;

 Ori_Width :=Width;
 Ori_Height:=Height;

 bm_Out.Width:=bm_In.Width;
 bm_Out.Height:=bm_In.Height;

 bm_In.PixelFormat := pf32bit;
 bm_Out.PixelFormat := pf32bit;



 Pbm_In := PLongArray(bm_In.ScanLine[Height-1]);
 Pbm_Out := PLongArray(bm_Out.ScanLine[Height-1]);

 setlength(Gray_In,Width*Height);
 setlength(Work_In,Width*Height);
 setlength(Tmp_In,Width*Height);
 setlength(seamsFinded,Width*Height);
 setlength(Energy,Width*Height);
 setlength(Map,Width*Height);
 seamsFindedCount:=0;

 MakeGrayScale(Pbm_In);                           { Pbm_In => Gray_In }
 GaussianBlur(GaussSize,GaussTheta);              { Gray_In => Work_In }
 Sobel;                                           { Work_In => Energy }

 if Step=0 then
  begin
   ShowBuff(Energy);
   ClearBuff;
   exit;
  end;

 setlength(SeamsPath,Width);
 fillchar(seamsFinded[0],Ori_Width*Ori_Height*sizeof(integer),0);
 // traitement horizontal (diminution de la hauteur)
 while CropHeight>0 do
 begin
  FindSeamsH;     { Energy => SeamsPath }
  updateSeamMapH; { SeamsPath => seamsFinded }
  CompressH;      { Work_In => Work_In }
  UpdateEnergyH;  { Energy => Energy }
  dec(Height);
  dec(CropHeight);
 end;

 if Step=2 then
  begin
   ShowSeams(false);
   ClearBuff;
   exit;
  end;
 if Step=4 then
  begin
   copyimage(Pbm_In,Tmp_In);
   ShowSeams(true);
   ClearBuff;
   exit;
  end;

 reduceimageH(Pbm_In,Tmp_In);                     { Pbm_In => Tmp_In }


 MakeGrayScale(Tmp_In);                           { Gray_In => Gray_In }
 GaussianBlur(GaussSize,GaussTheta);              { Gray_In => Work_In }
 Sobel;                                           { Work_In => Energy }


 seamsFindedCount:=0;
 setlength(SeamsPath,Height);
 fillchar(seamsFinded[0],Ori_Width*Ori_Height*sizeof(integer),0);
 // traitement vertical (diminution de la largeur)
 while CropWidth>0 do
 begin
  FindSeamsV;     { Energy => SeamsPath }
  updateSeamMapV; { SeamsPath => seamsFinded }
  CompressV;      { Work_In => Work_In }
  UpdateEnergyV;  { Energy => Energy }
  dec(Width);
  dec(CropWidth);
 end;

 if Step=1 then
  begin
   ShowBuff(Energy);
   ClearBuff;
  end;

 if Step=3 then
  begin
   ShowSeams(false);
   ClearBuff;
   exit;
  end;

 if Step=5 then
  begin
   ShowSeams(true);
   ClearBuff;
   exit;
  end;

 if step=6 then reduceimageV(Tmp_In,Pbm_Out);

 bm_out.Canvas.Draw(0,Height-Ori_Height,bm_out);
 bm_out.Width:=Width;
 bm_out.Height:=Height;
end;

end.




{
STEP
0:Initial Energy
1:Final Energy
2:H. Seams Path
3:V. Seams Path
4:H. Seams Path in picture
5:V. Seams Path in picture
6:Final
}
