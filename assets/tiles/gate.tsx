<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.10.2" name="gate" tilewidth="34" tileheight="52" tilecount="3" columns="3" objectalignment="bottom">
 <tileoffset x="0" y="8"/>
 <grid orientation="isometric" width="64" height="32"/>
 <properties>
  <property name="Solid" type="bool" value="true"/>
 </properties>
 <image source="gate.png" width="102" height="52"/>
 <tile id="0">
  <objectgroup draworder="index" id="2">
   <object id="23" x="5" y="24" width="34.5" height="24"/>
  </objectgroup>
  <animation>
   <frame tileid="0" duration="50"/>
   <frame tileid="1" duration="50"/>
   <frame tileid="2" duration="50"/>
   <frame tileid="1" duration="50"/>
  </animation>
 </tile>
</tileset>
