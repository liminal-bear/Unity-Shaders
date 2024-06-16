//some aspects inspired by https://www.shadertoy.com/view/MtjGRd
Shader "worldHatch2"
{
	Properties
	{
		_MainTex("Main Texture", 2D) = "white" {}

		_ShadowColor("Shadow Color", Color) = (0,0,0,1)
		_ShadowSize("Shadow Size", Range(0,1)) = 0.297
		_ShadowGradient("Shadow Gradient", Range(0,1)) = 0

		_MinBrightnessLight("Minimum Brightness (Light)", Range(0, 1)) = 0.533
		_MinBrightnessShadow("Minimum Brightness (Shadow)", Range(0, 1)) = 0.108

		_LightColor("Light Color", Color) = (1, 1, 1, 1)

			//[Toggle] _UseNormal("Use Normal Map?", Int) = 0
			[NoScaleOffset] _NormalMap("Normal Map", 2D) = "bump" {} //for some reason, "bump" doesn't initialize properly, there is a fix for this down below
			_NormalStrength("Normal Strength", Range(0.0, 3.0)) = 1
			[HideInInspector][KeywordEnum(Opaque, Transparent, Custom)] _RenderPreset("Render Preset", Float) = 0
			[Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
			[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
			[Enum(Off, 0, On, 1)] _ZWrite("ZWrite", Int) = 1

			_Posterize("Posterization factor", Range(0.0,10)) = 2.1

			_DitherSize("Dither Size", Range(0,5)) = 0.48

			[Toggle] _UseCustomLight("Override light Color", Int) = 0

			_Threshold("Threshold", Range(0.0, 1.0)) = 0.5
			_Adjust("NdotL or NdotV", Range(0.0, 1.0)) = 0.6
			_Density("Density", Range(0.0, 1.0)) = 0.6

				//_ShadowColor("Shadow Color", Color) = (0, 0, 0, 1)
		_Hatch0("Hatch0", 2D) = "white" { }
		_Hatch1("Hatch1", 2D) = "white" { }
		_Hatch2("Hatch2", 2D) = "white" { }
		_Hatch3("Hatch3", 2D) = "white" { }
		_Hatch4("Hatch4", 2D) = "white" { }
		_Hatch5("Hatch5", 2D) = "white" { }

	}

		CGINCLUDE //shared includes, variables, and functions
		//#include "UnityCG.cginc"
		//#include "AutoLight.cginc"
		//#include "Lighting.cginc"
		//#ifndef AUTOLIGHT_FIXES_INCLUDED
		//#define AUTOLIGHT_FIXES_INCLUDED

		//#include "HLSLSupport.cginc"
		//#include "UnityShadowLibrary.cginc"

#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
//uniform float4 _LightColor0;
// color of light source (from "Lighting.cginc")

			// User-specified properties
		sampler2D _MainTex;
	uniform float4 _LightColor;
	uniform float4 _ShadowColor;
	uniform float _ShadowSize;
	uniform float _ShadowGradient;
	uniform float _MinBrightnessLight;
	uniform float _MinBrightnessShadow;

	uniform int _OverrideLightColor;
	uniform int _OverrideShadowColor;

	uniform float4 _MainTex_ST;

	uniform sampler2D _Hatch0;
	uniform sampler2D _Hatch1;
	uniform sampler2D _Hatch2;
	uniform sampler2D _Hatch3;
	uniform sampler2D _Hatch4;
	uniform sampler2D _Hatch5;

	uniform float _Threshold;
	uniform float _Adjust;
	uniform float _Density;

	uniform sampler2D _NormalMap;
	uniform float _NormalStrength;

	uniform int _Posterize;

	half _DitherSize;
	int _UseCustomLight;


#ifdef USING_STEREO_MATRICES
	static float3 centerCameraPos = 0.5 * (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]);
#else
	static float3 centerCameraPos = _WorldSpaceCameraPos;
#endif

	float toGrayscale(float3 input)
	{
		return (input.r + input.g + input.b) / 3;
	}

	float4 Unity_Posterize_float4(float4 In, float4 Steps)
	{
		return floor(In / (1 / Steps)) * (1 / Steps);
	}

	float3 Unity_Posterize_float3(float3 In, float3 Steps)
	{
		return floor(In / (1 / Steps)) * (1 / Steps);
	}


	float4 worldAlbedoSample(sampler2D tex, float4 ST, float3 normalWorld, float3 posWorld)
	{
		float3 projNormal = saturate(pow(normalWorld * 1.5, 4));
		float4 tangent = float4(0, 0, 0, 0);
		tangent.xyz = lerp(tangent.xyz, float3(0, 0, 1), projNormal.y);
		tangent.xyz = lerp(tangent.xyz, float3(0, 1, 0), projNormal.x);
		tangent.xyz = lerp(tangent.xyz, float3(1, 0, 0), projNormal.z);
		tangent.xyz = tangent.xyz - dot(tangent.xyz, normalWorld) * normalWorld;
		tangent.xyz = normalize(tangent.xyz);

		tangent.w = lerp(tangent.w, normalWorld.y, projNormal.y);
		tangent.w = lerp(tangent.w, -normalWorld.x, projNormal.x);
		tangent.w = lerp(tangent.w, normalWorld.z, projNormal.z);
		tangent.w = step(tangent.w, 0);
		tangent.w *= -2;
		tangent.w += 1;

		float3 binormal = cross(normalWorld, tangent.xyz) * tangent.w;
		float3x3 rotation = float3x3(tangent.xyz, binormal, normalWorld);

		// TEXTURE INPUTS USING WORLD POSITION BASED UVS
		//addad MainTex_ST for texture tiling and stretch
		half3 albedo0 = tex2D(tex, posWorld.xy * ST.xy + ST.zw).rgb;
		half3 albedo1 = tex2D(tex, posWorld.zx * ST.xy + ST.zw).rgb;
		half3 albedo2 = tex2D(tex, posWorld.zy * ST.xy + ST.zw).rgb;

		// BLEND TEXTURE INPUTS BASED ON WORLD NORMAL
		float3 worldAlbedo;
		worldAlbedo = lerp(albedo1, albedo0, projNormal.z);
		worldAlbedo = lerp(worldAlbedo, albedo2, projNormal.x);

		return float4(worldAlbedo, 1);
	}


	float3 HatchPalette(float x, float3 color1, float3 color2, float4 positionCS, float4 ST, float3 normalWorld, float3 posWorld, float3 Ndots)
	{
		fixed4 hatch0 = worldAlbedoSample(_Hatch0, ST, normalWorld, posWorld);
		fixed4 hatch1 = worldAlbedoSample(_Hatch1, ST, normalWorld, posWorld);
		fixed4 hatch2 = worldAlbedoSample(_Hatch2, ST, normalWorld, posWorld);
		fixed4 hatch3 = worldAlbedoSample(_Hatch3, ST, normalWorld, posWorld);
		fixed4 hatch4 = worldAlbedoSample(_Hatch4, ST, normalWorld, posWorld);
		fixed4 hatch5 = worldAlbedoSample(_Hatch5, ST, normalWorld, posWorld);

		//if (length(lightColorized.rgb * 99) < _Threshold)
//            {
		float3 col = float3(1, 1, 1);

		float3 diffuse = col * Ndots.y;
		float intensity = lerp(saturate(x), 0.5 * saturate(dot(x, half3(0.2326, 0.7152, 0.0722))), _Density);
		//float intensity = lerp(diffuse, 0.5 * saturate(dot(diffuse, half3(0.2326, 0.7152, 0.0722))), _Density);

		if (0.6 < intensity)
		{
			col *= fixed4(1, 1, 1, 1);
		}
		else if (0.5 < intensity && intensity <= 0.6)
		{
			col *= lerp(hatch0, hatch1, 1 - intensity);
		}
		else if (0.4 < intensity && intensity <= 0.5)
		{
			col *= lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity);
		}
		else if (0.3 < intensity && intensity <= 0.4)
		{
			col *= lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity);
		}
		else if (0.2 < intensity && intensity <= 0.3)
		{
			col *= lerp(lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity), hatch4, 1 - intensity);
		}
		else if (0.1 < intensity && intensity <= 0.2)
		{
			col *= lerp(lerp(lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity), hatch4, 1 - intensity), hatch4, 1 - intensity);
		}
		else if (intensity <= 0.1)
		{
			col *= lerp(lerp(lerp(lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity), hatch4, 1 - intensity), hatch4, 1 - intensity), hatch5 * 0.5, Ndots.y * 1.5);
		}
		//}
		//else
		//{
		//    float manipulate = lerp(NdotL, NdotV, _Adjust);
		//    float3 diffuse = lerp(col.rgb * manipulate, lightColorized, 1.0 / pow(3, length(lightColorized)));
		//    float intensity = lerp(saturate(length(diffuse)), 0.5 * saturate(dot(diffuse, half3(0.2326, 0.7152, 0.0722))), _Density);

		//    if(0.6 < intensity)
		//    {
		//        col *= fixed4(1, 1, 1, 1);
		//    }
		//    else if(0.5 < intensity && intensity <= 0.6)
		//    {
		//        col *= lerp(hatch0, hatch1, 1 - intensity);
		//    }
		//    else if(0.4 < intensity && intensity <= 0.5)
		//    {
		//        col *= lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity);
		//    }
		//    else if(0.3 < intensity && intensity <= 0.4)
		//    {
		//        col *= lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity);
		//    }
		//    else if(0.2 < intensity && intensity <= 0.3)
		//    {
		//        col *= lerp(lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity), hatch4, 1 - intensity);
		//    }
		//    else if(0.1 < intensity && intensity <= 0.2)
		//    {
		//        col *= lerp(lerp(lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity), hatch4, 1 - intensity), hatch4, 1 - intensity);
		//    }
		//    else if(intensity <= 0.1)
		//    {
		//        col *= lerp(lerp(lerp(lerp(lerp(lerp(hatch0, hatch1, 1 - intensity), hatch2, 1 - intensity), hatch3, 1 - intensity), hatch4, 1 - intensity), hatch4, 1 - intensity), hatch5 * 0.5, (1 - NdotL) * 1.5);
		//    }
		//}

		//return float4(col,1);

		return lerp(color1, color2, col.r);
	}

	struct vertexInput
	{
		float4 vertex : POSITION;
		float4 texcoord : TEXCOORD0;
		float3 normal : NORMAL;
		float4 tangent : TANGENT;
	};
	struct vertexOutput
	{
		float4 pos : SV_POSITION;
		float4 posWorld : TEXCOORD0;
		// position of the vertex (and fragment) in world space 
		float4 tex : TEXCOORD1;
		float3 tangentWorld : TEXCOORD2;
		float3 normalWorld : TEXCOORD3;
		float3 binormalWorld : TEXCOORD4;
		fixed3 vLight : COLOR;
		fixed3 vLightFlat : COLOR1;

		float normal : TEXCOORD5;


		//LIGHTING_COORDS(5, 6)
		UNITY_LIGHTING_COORDS(6, 7)
			//V2F_SHADOW_CASTER
	};

	vertexOutput vert(vertexInput input)
	{
		vertexOutput output;

		float4x4 modelMatrix = unity_ObjectToWorld;
		float4x4 modelMatrixInverse = unity_WorldToObject;

		output.tangentWorld = normalize(
			mul(modelMatrix, float4(input.tangent.xyz, 0.0)).xyz);
		output.normalWorld = normalize(
			mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);
		output.binormalWorld = normalize(
			cross(output.normalWorld, output.tangentWorld)
			* input.tangent.w); // tangent.w is specific to Unity

		output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
		output.tex = input.texcoord;
		output.pos = UnityObjectToClipPos(input.vertex);

		output.normal = input.normal;
		half3 worldN = UnityObjectToWorldNormal(input.normal);
		half3 shlight = ShadeSH9(float4(worldN, 1.0));
		output.vLight = shlight;
		half3 shlightFlat = ShadeSH9(float4(.2, 1, .2, 1.0));
		output.vLightFlat = shlightFlat;
		return output;
	}


	ENDCG
		SubShader
	{
		Tags
		{
			"LightMode" = "ForwardBase"
			"Queue" = "Geometry"
		//"Queue" = "AlphaTest"
		"RenderType" = "Opaque"
		//"IgnoreProjector" = "False"
		//"RenderType" = "TransparentCutout"
	}

	ZWrite[_ZWrite]
	Ztest[_ZTest]

	Blend SrcAlpha OneMinusSrcAlpha // use alpha blending
	Pass
	{
			//AlphaToMask On
			Cull[_Cull]
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase
			#pragma target 3.0

			float4 frag(vertexOutput input) : COLOR
			{
			// in principle we have to normalize tangentWorld,
			// binormalWorld, and normalWorld again; however, the 
			// potential problems are small since we use this 
			// matrix only to compute "normalDirection", 
			// which we normalize anyways

			float4 col = tex2D(_MainTex, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
			//col.a = _Opacity;
			//col.a = (1 - tex.a) * (_TintColor.a * i.color.a * 2.0f);


			float4 encodedNormal = tex2D(_NormalMap,input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
			//807fff
			encodedNormal = encodedNormal == (0, 0, 0, 1) ? (0.5, 0.5, 1, 0.5) : encodedNormal;
			encodedNormal = lerp(half4(0.5, 0.5, 0.5, .5), encodedNormal, _NormalStrength);

			float3 localCoords = float3(2.0 * encodedNormal.a - 1.0,
				2.0 * encodedNormal.g - 1.0, 0.0);

			 localCoords.z = 1.0 - 0.5 * dot(localCoords, localCoords);

			float3x3 local2WorldTranspose = float3x3(
			input.tangentWorld,
			input.binormalWorld,
			input.normalWorld);
			float3 normalDirection =
			normalize(mul(localCoords, local2WorldTranspose));

			float3 viewDirection = normalize(
			_WorldSpaceCameraPos - input.posWorld.xyz);
			float3 lightDirection;



			//float attenuation = 0;
#ifdef USING_DIRECTIONAL_LIGHT
					//lightDirection = _WorldSpaceLightPos0;
#else
					//lightDirection = _WorldSpaceLightPos0 - input.posWorld;
#endif
					//UNITY_LIGHT_ATTENUATION(attenuation, input, input.posWorld.xyz);
					float attenuation = 1;
					if (0.0 == _WorldSpaceLightPos0.w) // directional light?
					{
						//attenuation = 1.0; // no attenuation
						lightDirection = normalize(_WorldSpaceLightPos0.xyz);
						lightDirection = float3(.5, 0.5, .5);
					}
					else // point or spot light
					{
						float3 vertexToLightSource =
							_WorldSpaceLightPos0.xyz - input.posWorld.xyz;
						float distance = length(vertexToLightSource);
						//attenuation = 1.0 / distance; // linear attenuation 
						lightDirection = normalize(vertexToLightSource);
						lightDirection = float3(.5, 0.5, .5);
					}


					float3 tangentNormal = float4(UnpackNormal(tex2D(_NormalMap, input.tex)), 1);
					float3x3 TBN = float3x3(input.tangentWorld, input.binormalWorld, input.normalWorld);
					TBN = transpose(TBN);
					float3 worldNormal = mul(TBN, tangentNormal);
					float3 N = lerp(input.normal, worldNormal, saturate(length(tangentNormal) * 100));
					//float3 viewDirection = normalize(_WorldSpaceCameraPos - input.posWorld.xyz);


					float3 V = normalize(centerCameraPos.xyz - input.posWorld.xyz);
					float NdotV = max(0, dot(N, V));
					float NNdotV = 1.01 - dot(N, V);

					float NdotL = max(0, dot(lightDirection, N));

					float3 ndots = float3(NdotV, NdotL, NNdotV);

					//normalDirection = Unity_Posterize_float3(normalDirection, _Posterize);
					//lightDirection = Unity_Posterize_float3(lightDirection, _Posterize);

					//float3 diffuseReflection = attenuation * _LightColor0.rgb * max(0.0, dot(normalDirection, lightDirection));
					//float3 specularReflection;

					//attenuation = LIGHT_ATTENUATION(input);

					float3 ambientLighting = UNITY_LIGHTMODEL_AMBIENT.rgb;

					//float4 lightProbeLighting;
					//lightProbeLighting.rgb = input.vLight;

					//half3 worldViewDir = normalize(UnityWorldSpaceViewDir(input.posWorld));
					//half3 reflection = reflect(-worldViewDir, normalDirection);

					_ShadowSize = -1 * (_ShadowSize - 1);
					_ShadowGradient = -1 * (_ShadowGradient - 1);

					float4 lightProbeLighting;
					float4 lightProbeColor = float4(max(0, ShadeSH9(float4(N, 1))),1);
					lightProbeColor.rgb = input.vLightFlat;

					int isLit = lightDirection >= float3(0, 0, 0) ? 1 : 0;
					//if (isLit == 0)
					//{
					//	_LightColor0.rgb = lightProbeColor.rgb;
					//	//lightDirection = float3(_Adjust1, _Adjust2, _Adjust3);
					//	//lightDirection = float3(.5, 0.5, .5);
					//}
					//else
					//{
					//	_LightColor0.rgb += lightProbeColor.rgb;
					//}
					//float light = pow(dot(normalDirection, lightDirection) + (_ShadowSize * 2) - .5 + (.5 * _ShadowGradient), 1 + pow(1 + _ShadowGradient, 12 * _ShadowGradient));
					float light = pow(dot(normalDirection, lightDirection) + (_ShadowSize * 2) - .5 + (.5 * _ShadowGradient), 1 + pow(1 + _ShadowGradient, 12 * _ShadowGradient));
					light = clamp(light, 0.000001, 1);
					light = clamp(light, lerp(_MinBrightnessShadow, _MinBrightnessLight, light), 1);
					//light += _MinBrightness;

					float3 lightColorized = light * lerp(_OverrideShadowColor == 0 ? clamp(_LightColor0.rgb, _MinBrightnessShadow, 2) : clamp(_ShadowColor, _MinBrightnessShadow, 2),
						_OverrideLightColor == 0 ? clamp(_LightColor0.rgb, _MinBrightnessLight, 2) : clamp(_LightColor, _MinBrightnessLight, 2),
						light);
					lightColorized += lerp(_OverrideShadowColor == 0 ? ambientLighting : 0,
						_OverrideLightColor == 0 ? ambientLighting : 0,
						light);

					//lightColorized.rgb += max(0, ShadeSH9(float4(N, 1)));


					//float3 lightSum = ambientLighting + diffuseReflection + lightProbeLighting;
					//float3 realCol = toGrayscale(lightColorized);
					float3 realCol = lightColorized;
					//col.rgb = col * lerp((ambientLighting + diffuseReflection + lightProbeLighting), 1, metallic);
					//col.rgb = lerp(col.rgb , skyColor * col.rgb, min(1, -(col.a - 1) + metallic + Smoothness * .07));
					//col.rgb = lerp(col.rgb, skyColor * 2, min(1, skyFresnel + 0.02) * Smoothness);

					//col.a = min(1, col.a + .1 * specularReflection);

					//realCol = Unity_Posterize_float3(realCol, _Posterize).rgb;

					//float3 lightLerp = _UseCustomLight == 1 ? _LightColor : ambientLighting + input.vLightFlat + _LightColor0.rgb;
					float3 lightLerp = _UseCustomLight == 1 ? _LightColor : input.vLightFlat + _LightColor0.rgb;


					//realCol = HatchPalette(realCol.r, input.pos);
					//realCol = HatchPalette(realCol.r,  _ShadowColor, _LitColor, input.pos);
					realCol = HatchPalette(toGrayscale(realCol) * 1, _ShadowColor, lightLerp, input.pos, float4(4,4,0,0), input.normalWorld, input.posWorld, ndots);

					//realCol = lerp(_LitColor, _ShadowColor, realCol.r);
					//realCol = lerp(_ShadowColor, _LitColor,  realCol.r);

					////col.rgb = Unity_Posterize_float3(col.rgb, _Posterize);

					col.rgb *= realCol;

					//return float4(input.vLightFlat + _LightColor0.rgb,1);
					return float4(col.rgb, 1);

			}
			ENDCG
		}

			Pass
			{
				Tags {"LightMode" = "ShadowCaster"}
				CGPROGRAM
				#pragma vertex vertSShadow
				#pragma fragment fragSShadow
				float4 vertSShadow(float4 vertex : POSITION) : SV_POSITION{
					float4 clipPos = UnityObjectToClipPos(vertex.xyz);
					clipPos.z = lerp(clipPos.z,min(clipPos.z, clipPos.w * UNITY_NEAR_CLIP_VALUE), unity_LightShadowBias.y);
					return clipPos;
				}
				fixed4 fragSShadow(float4 pos : SV_POSITION) : SV_Target{return 0;}
				ENDCG
			}
	}
		Fallback "Diffuse"
}