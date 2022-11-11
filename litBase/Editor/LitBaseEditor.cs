using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System;

public class LitBaseEditor : ShaderGUI
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

        MaterialProperty tintColor = FindProperty("_TintColor", properties);
        //GUIContent tintColorLabel = new GUIContent("Tint Color", "Texture to determine glow location");

        //MaterialProperty emissionColor = FindProperty("_EmissionColor", properties);

        editor.TexturePropertySingleLine(mainTexLabel, mainTex, tintColor);


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

		

        
        //GUIContent normalScaleLabel = new GUIContent("Normal Strength", "Defines Bumpiness Strength");
        //editor.ShaderProperty(normalScaleSlider, normalScaleLabel);

        


        MaterialProperty metallicMap = FindProperty("_MetallicMap", properties);
        GUIContent metallicMapLabel = new GUIContent("Metallic Map", "Defines metalness");
        MaterialProperty metallicScaleSlider = FindProperty("_MetallicScale", properties);
        editor.TexturePropertySingleLine(metallicMapLabel, metallicMap, metallicScaleSlider);

        MaterialProperty roughnessMap = FindProperty("_RoughnessMap", properties);
        GUIContent roughnessMapLabel = new GUIContent("Roughness Map", "Defines shininess");
        MaterialProperty RoughnessScaleSlider = FindProperty("_RoughnessScale", properties);
        editor.TexturePropertySingleLine(roughnessMapLabel, roughnessMap, RoughnessScaleSlider);

        //tiling for maintex tiles all maps
        editor.TextureScaleOffsetProperty(mainTex);

        GUILayout.Label(" ", EditorStyles.boldLabel);
        GUILayout.Label("Lighting", EditorStyles.boldLabel);

        MaterialProperty diffColor = FindProperty("_DiffColor", properties);
		GUIContent diffColorLabel = new GUIContent("Diffuse Color", "Color of diffuse lighting");
		editor.ShaderProperty(diffColor, diffColorLabel);

        MaterialProperty specColor = FindProperty("_SpecColor", properties);
		GUIContent specColorLabel = new GUIContent("Specular Color", "Color of specular highlights");
		editor.ShaderProperty(specColor, specColorLabel);

        MaterialProperty specularScaleSlider = FindProperty("_Specular", properties);
        GUIContent specularScaleLabel = new GUIContent("Specular Intensity", "Intensity of specular highlights");
        editor.ShaderProperty(specularScaleSlider, specularScaleLabel);

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


   

        //CullSettings CullSettings = CullSettings.Back;

        //EditorGUI.BeginChangeCheck();
        //EditorGUILayout.EnumPopup(cullLabel, CullSettings);
        //if (EditorGUI.EndChangeCheck())
        //{


        //}

        //EditorGUILayout.EnumPopup(cullLabel, CullSettings);
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
        GUILayout.Label("Rendering", EditorStyles.boldLabel);

        MaterialProperty renderPreset = FindProperty("_RenderPreset", properties);
        GUIContent renderPresetLabel = new GUIContent("Render Preset", "Quick way to set transparency");
        editor.ShaderProperty(renderPreset, renderPresetLabel);

 



        MaterialProperty opacity = FindProperty("_Opacity", properties);
        GUIContent opacityLabel = new GUIContent("Opacity", "Transparency of entire object");
        editor.ShaderProperty(opacity, opacityLabel);

        //MaterialProperty glassOpacity = FindProperty("_GlassOpacity", properties);
        //GUIContent glassOpacityLabel = new GUIContent("Glass Opacity", "Transparency while preserving lighting");
        //editor.ShaderProperty(glassOpacity, glassOpacityLabel);

        MaterialProperty cull = FindProperty("_Cull", properties);
        GUIContent cullLabel = new GUIContent("Culling Mode", "Face discard settings");
        editor.ShaderProperty(cull, cullLabel);

        MaterialProperty zWrite = FindProperty("_ZWrite", properties);
        GUIContent zWriteLabel = new GUIContent("ZWrite", "Controls depth buffer writing of object");
        editor.ShaderProperty(zWrite,zWriteLabel);

        MaterialProperty zTest = FindProperty("_ZTest", properties);
        GUIContent zTestLabel = new GUIContent("ZTest", "Controls occlusion/occluding of object");
        editor.ShaderProperty(zTest, zTestLabel);

        editor.RenderQueueField();

        switch (renderPreset.floatValue)
        {
            case 0://opaque
                material.renderQueue = 2000;
                zWrite.floatValue = 1;
                zTest.floatValue = 4;
                break;
            case 1://transparent
                material.renderQueue = 3000;
                zWrite.floatValue = 0;
                break;
            case 2://Custom
                //do nothing
                break;
            default:
                //this should not happen
                break;
        }

    }

}
