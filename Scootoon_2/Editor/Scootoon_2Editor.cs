using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System;

public class Scootoon_2Editor : ShaderGUI
{
    MaterialEditor editor;
    MaterialProperty[] properties;
    Material material;
    int renderQueue;
    enum CullSettings { Off, Front, Back }
    enum RenderPreset { Opaque, Transparent, Custom }

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        this.editor = materialEditor;
        this.properties = properties;
        this.material = materialEditor.target as Material;
        renderQueue = material.renderQueue;
        DrawUI();
    }

    void DrawUI()
    {
        GUILayout.Label("Main Maps", EditorStyles.boldLabel);

        MaterialProperty mainTex = FindProperty("_MainTex", properties);
        GUIContent mainTexLabel = new GUIContent("Main Texture", "Basic color");

        editor.TexturePropertySingleLine(mainTexLabel, mainTex);

        MaterialProperty normalMap = FindProperty("_NormalMap", properties);

        GUIContent normalMapLabel = new GUIContent("Normal Map", "Defines bumpiness");
        if (normalMap.textureValue == null)
        {
            editor.TexturePropertySingleLine(normalMapLabel, normalMap);
        }
        else
        {
            MaterialProperty normalScaleSlider = FindProperty("_NormalStrength", properties);
            editor.TexturePropertySingleLine(normalMapLabel, normalMap, normalScaleSlider);
        }


        GUILayout.Label(" ", EditorStyles.boldLabel);
        GUILayout.Label("Matcap", EditorStyles.boldLabel);

        MaterialProperty useMatcap = FindProperty("_UseMatcap", properties);
        GUIContent useMatcapLabel = new GUIContent("Enable Matcap", "Used to simulate other materials, mostly metals");
        editor.ShaderProperty(useMatcap, useMatcapLabel);
        if (useMatcap.floatValue == 1)
        {

            MaterialProperty matcapTex = FindProperty("_MatcapTex", properties);
            GUIContent matcapTexLabel = new GUIContent("Matcap Texture", "picture of material to simulate");
            if (matcapTex.textureValue != null)
            {
                MaterialProperty metallicScaleSlider = FindProperty("_MatcapScale", properties);
                editor.TexturePropertySingleLine(matcapTexLabel, matcapTex, metallicScaleSlider);
                MaterialProperty matcapMask = FindProperty("_MatcapMask", properties);
                GUIContent matcapMaskLabel = new GUIContent("Matcap Mask", "Defines metalness");
                editor.TexturePropertySingleLine(matcapMaskLabel, matcapMask);
            }
            else
            {
                editor.TexturePropertySingleLine(matcapTexLabel, matcapTex);
            }
        }

        GUILayout.Label(" ", EditorStyles.boldLabel);
        GUILayout.Label("Light & Shadow", EditorStyles.boldLabel);

        MaterialProperty emissionToggle = FindProperty("_UseEmission", properties);
        GUIContent emissionToggleLabel = new GUIContent("Emission", "Enables a glowing texture");
        editor.ShaderProperty(emissionToggle, emissionToggleLabel);
        if (emissionToggle.floatValue == 1)
        {
            MaterialProperty emission = FindProperty("_Emission", properties);
            GUIContent emissionLabel = new GUIContent("Color", "Texture to determine glow location");

            MaterialProperty emissionColor = FindProperty("_EmissionColor", properties);

            editor.TexturePropertySingleLine(emissionLabel, emission, emissionColor);
        }

        MaterialProperty minBrightnessLight = FindProperty("_MinBrightnessLight", properties);
		GUIContent minBrightnessLightLabel = new GUIContent("Minumum Brightness (Light)", "Mininum brightness for lit areas");
		editor.ShaderProperty(minBrightnessLight, minBrightnessLightLabel);

        MaterialProperty minBrightnessShadow = FindProperty("_MinBrightnessShadow", properties);
        GUIContent minBrightnessShadowLabel = new GUIContent("Minumum Brightness (Shadow)", "Minimum brightness for shadows");
        editor.ShaderProperty(minBrightnessShadow, minBrightnessShadowLabel);

        MaterialProperty lightOverride = FindProperty("_OverrideLightColor", properties);
        GUIContent lightOverrideLabel = new GUIContent("Override light colors?", "Decides to use custom colors for bright areas");
        editor.ShaderProperty(lightOverride, lightOverrideLabel);

        if (lightOverride.floatValue == 1)
        {
            MaterialProperty lightColor = FindProperty("_LightColor", properties);
            GUIContent lightColorLabel = new GUIContent("Light color", "custom color for bright areas");
            editor.ShaderProperty(lightColor, lightColorLabel);
        }

        MaterialProperty shadowOverride = FindProperty("_OverrideShadowColor", properties);
        GUIContent shadowOverrideLabel = new GUIContent("Override shadow colors?", "Decides to use custom colors for bright areas");
        editor.ShaderProperty(shadowOverride, shadowOverrideLabel);

        if (shadowOverride.floatValue == 1)
        {
            MaterialProperty shadowColor = FindProperty("_ShadowColor", properties);
            GUIContent shadowColorLabel = new GUIContent("Shadow Color", "Tint color for shadow");
            editor.ShaderProperty(shadowColor, shadowColorLabel);
        }

        MaterialProperty shadowSize = FindProperty("_ShadowSize", properties);
        GUIContent shadowSizeLabel = new GUIContent("Shadow Size", "Size of shadow");
        editor.ShaderProperty(shadowSize, shadowSizeLabel);

        MaterialProperty shadowGradient = FindProperty("_ShadowGradient", properties);
        GUIContent shadowGradientLabel = new GUIContent("Shadow Gradient", "Sharpness of shadow");
        editor.ShaderProperty(shadowGradient, shadowGradientLabel);

        GUILayout.Label(" ", EditorStyles.boldLabel);
        GUILayout.Label("FX", EditorStyles.boldLabel);

        MaterialProperty adjustMask = FindProperty("_AdjustMask", properties);
        GUIContent adjustMaskLabel = new GUIContent("Color adjustment mask", "determines where colors should be adjusted");
        editor.TexturePropertySingleLine(adjustMaskLabel, adjustMask);

        MaterialProperty hue = FindProperty("_Hue", properties);
        GUIContent hueLabel = new GUIContent("Hue", "Hue color adjust");
        editor.ShaderProperty(hue, hueLabel);

        MaterialProperty sat = FindProperty("_Sat", properties);
        GUIContent satLabel = new GUIContent("Sat", "Saturation color adjust");
        editor.ShaderProperty(sat, satLabel);

        MaterialProperty bright = FindProperty("_Bright", properties);
        GUIContent brightLabel = new GUIContent("Brightness", "Brightness color adjust");
        editor.ShaderProperty(bright, brightLabel);

        GUILayout.Label(" ", EditorStyles.boldLabel);
        GUILayout.Label("Outlines", EditorStyles.boldLabel);

        MaterialProperty OutlineTex = FindProperty("_OutlineTex", properties);
        GUIContent OutlineTexLabel = new GUIContent("Outline Color", "Color of outline");

        MaterialProperty outlineColor = FindProperty("_OutlineColor", properties);
        GUIContent outlineColorLabel = new GUIContent("Outline Color", "Color of outline");
        editor.TexturePropertySingleLine(OutlineTexLabel, OutlineTex, outlineColor);

        MaterialProperty OutlineWidthMask = FindProperty("_OutlineWidthMask", properties);
        GUIContent OutlineWidthMaskLabel = new GUIContent("Outline Width Mask", "Color of outline");
        editor.TexturePropertySingleLine(OutlineWidthMaskLabel, OutlineWidthMask);

        MaterialProperty outlineWidth = FindProperty("_OutlineWidth", properties);
        GUIContent outlineLabel = new GUIContent("Outline Width", "Width of outline");
        editor.ShaderProperty(outlineWidth, outlineLabel);
        
    }

}
