import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

class ThemePreset {
 final String id,name,category; final Color accent,secondary,background; final bool light;
 const ThemePreset(this.id,this.name,this.category,this.accent,this.secondary,this.background,{this.light=false});
}
const themePresets=<ThemePreset>[
ThemePreset('nebula','Nebula','Featured',Color(0xFF7C4DFF),Color(0xFF18FFFF),Color(0xFF05060F)),
ThemePreset('dracula','Dracula','Stylized',Color(0xFFBD93F9),Color(0xFFFF79C6),Color(0xFF282A36)),
ThemePreset('nord','Nord','Stylized',Color(0xFF88C0D0),Color(0xFF81A1C1),Color(0xFF2E3440)),
ThemePreset('tokyo','Tokyo Night','Stylized',Color(0xFF7AA2F7),Color(0xFFBB9AF7),Color(0xFF1A1B26)),
ThemePreset('cat-mocha','Catppuccin Mocha','Stylized',Color(0xFFCBA6F7),Color(0xFFF5C2E7),Color(0xFF1E1E2E)),
ThemePreset('cat-macchiato','Catppuccin Macchiato','Stylized',Color(0xFFC6A0F6),Color(0xFFF5BDE6),Color(0xFF24273A)),
ThemePreset('gruvbox','Gruvbox Dark','Stylized',Color(0xFFFABD2F),Color(0xFFFE8019),Color(0xFF282828)),
ThemePreset('one-dark','One Dark','Stylized',Color(0xFF61AFEF),Color(0xFFC678DD),Color(0xFF282C34)),
ThemePreset('monokai','Monokai','Stylized',Color(0xFFA6E22E),Color(0xFFF92672),Color(0xFF272822)),
ThemePreset('synthwave','Synthwave','Stylized',Color(0xFFFF71CE),Color(0xFF01CDFE),Color(0xFF190D2B)),
ThemePreset('cyberpunk','Cyberpunk','Stylized',Color(0xFFFCEE0A),Color(0xFF00F0FF),Color(0xFF080A18)),
ThemePreset('matrix','Matrix','Stylized',Color(0xFF00FF66),Color(0xFF8AFF80),Color(0xFF020805)),
ThemePreset('vaporwave','Vaporwave','Stylized',Color(0xFFFF71CE),Color(0xFFB967FF),Color(0xFF241038)),
ThemePreset('midnight','Midnight','Dark',Color(0xFF6C8CFF),Color(0xFF9B8CFF),Color(0xFF090D1B)),
ThemePreset('amoled','AMOLED Black','Dark',Color(0xFFBB86FC),Color(0xFF03DAC6),Color(0xFF000000)),
ThemePreset('deep-space','Deep Space','Dark',Color(0xFF6D5DFB),Color(0xFF36D7E8),Color(0xFF070B20)),
ThemePreset('nightfall','Nightfall','Dark',Color(0xFF8E7CFF),Color(0xFF6ED6C5),Color(0xFF11121C)),
ThemePreset('ocean','Ocean','Dark',Color(0xFF2196F3),Color(0xFF26C6DA),Color(0xFF071B2B)),
ThemePreset('arctic','Arctic','Dark',Color(0xFF80DEEA),Color(0xFF90CAF9),Color(0xFF101C2C)),
ThemePreset('forest','Forest','Dark',Color(0xFF66BB6A),Color(0xFFAED581),Color(0xFF0D1A12)),
ThemePreset('crimson','Crimson','Dark',Color(0xFFFF5252),Color(0xFFFF8A80),Color(0xFF1C0A10)),
ThemePreset('ember','Ember','Dark',Color(0xFFFF7043),Color(0xFFFFCA28),Color(0xFF21100B)),
ThemePreset('solar','Solar','Dark',Color(0xFFFFCA28),Color(0xFFFF8F00),Color(0xFF201B0D)),
ThemePreset('neon-pink','Neon Pink','Dark',Color(0xFFFF2DAA),Color(0xFF8C52FF),Color(0xFF190817)),
ThemePreset('snow','Snow','Light',Color(0xFF536DFE),Color(0xFF00ACC1),Color(0xFFF5F7FB),light:true),
ThemePreset('arctic-light','Arctic Light','Light',Color(0xFF1976D2),Color(0xFF00838F),Color(0xFFEAF3FA),light:true),
ThemePreset('nord-light','Nord Light','Light',Color(0xFF5E81AC),Color(0xFF88C0D0),Color(0xFFECEFF4),light:true),
ThemePreset('cat-latte','Catppuccin Latte','Light',Color(0xFF8839EF),Color(0xFFEA76CB),Color(0xFFEFF1F5),light:true),
ThemePreset('solarized-light','Solarized Light','Light',Color(0xFF268BD2),Color(0xFF2AA198),Color(0xFFFDF6E3),light:true),
ThemePreset('paper','Paper','Light',Color(0xFF455A64),Color(0xFF00897B),Color(0xFFF7F4EE),light:true),
];
class ThemeSettingsState {
 final String presetId; final int? accentOverride,backgroundOverride; final bool starfieldEnabled; final Set<String> favorites;
 const ThemeSettingsState({this.presetId='nebula',this.accentOverride,this.backgroundOverride,this.starfieldEnabled=true,this.favorites=const{}});
 ThemePreset get preset=>themePresets.firstWhere((p)=>p.id==presetId,orElse:()=>themePresets.first);
 Color get accent=>Color(accentOverride??preset.accent.value); Color get background=>Color(backgroundOverride??preset.background.value);
 ThemeSettingsState copyWith({String? presetId,int? accentOverride,int? backgroundOverride,bool clearAccent=false,bool clearBackground=false,bool? starfieldEnabled,Set<String>? favorites})=>ThemeSettingsState(presetId:presetId??this.presetId,accentOverride:clearAccent?null:(accentOverride??this.accentOverride),backgroundOverride:clearBackground?null:(backgroundOverride??this.backgroundOverride),starfieldEnabled:starfieldEnabled??this.starfieldEnabled,favorites:favorites??this.favorites);
}
class ThemeSettingsNotifier extends StateNotifier<ThemeSettingsState>{
 final Box<String> _box=Hive.box<String>('prefs'); ThemeSettingsNotifier():super(_load());
 static ThemeSettingsState _load(){final b=Hive.box<String>('prefs');int? parse(String? s)=>s==null?null:int.tryParse(s);Set<String> fav={};try{fav=(jsonDecode(b.get('themeFavorites',defaultValue:'[]')!) as List).cast<String>().toSet();}catch(_){}return ThemeSettingsState(presetId:b.get('themePreset',defaultValue:'nebula')!,accentOverride:parse(b.get('themeAccent')),backgroundOverride:parse(b.get('themeBackground')),starfieldEnabled:b.get('starfieldEnabled',defaultValue:'true')=='true',favorites:fav);}
 void _save(ThemeSettingsState s){state=s;_box.put('themePreset',s.presetId);if(s.accentOverride==null){_box.delete('themeAccent');}else{_box.put('themeAccent',s.accentOverride.toString());}if(s.backgroundOverride==null){_box.delete('themeBackground');}else{_box.put('themeBackground',s.backgroundOverride.toString());}_box.put('starfieldEnabled',s.starfieldEnabled.toString());_box.put('themeFavorites',jsonEncode(s.favorites.toList()));}
 void selectPreset(String id)=>_save(state.copyWith(presetId:id,clearAccent:true,clearBackground:true)); void setAccent(Color c)=>_save(state.copyWith(accentOverride:c.value)); void setBackground(Color c)=>_save(state.copyWith(backgroundOverride:c.value)); void resetCustomColors()=>_save(state.copyWith(clearAccent:true,clearBackground:true)); void setStarfield(bool v)=>_save(state.copyWith(starfieldEnabled:v));
 void toggleFavorite(String id){final n={...state.favorites};if(!n.add(id))n.remove(id);_save(state.copyWith(favorites:n));}
}
final themeSettingsProvider=StateNotifierProvider<ThemeSettingsNotifier,ThemeSettingsState>((_)=>ThemeSettingsNotifier());
