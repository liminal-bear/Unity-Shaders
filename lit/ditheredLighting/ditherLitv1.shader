//some aspects inspired by https://www.shadertoy.com/view/MtjGRd
Shader "ditherLit"
{
	Properties
	{
		_MainTex("Main Texture", 2D) = "white" {}
		_LitColor("Lit Color", Color) = (1,1,1,1)
		_ShadowColor("Shadow Color", Color) = (0,0,0,1)

		//[Toggle] _UseNormal("Use Normal Map?", Int) = 0
		[NoScaleOffset] _NormalMap("Normal Map", 2D) = "bump" {} //for some reason, "bump" doesn't initialize properly, there is a fix for this down below
		_NormalStrength("Normal Strength", Range(0.0, 3.0)) = 1
		[HideInInspector][KeywordEnum(Opaque, Transparent, Custom)] _RenderPreset("Render Preset", Float) = 0
		[Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
		[Enum(Off, 0, On, 1)] _ZWrite("ZWrite", Int) = 1

		_Posterize("Posterization factor", Range(0.0,3)) = 2.1

		_DitherSize("Dither Size", Range(0,5)) = 0.48

		[Toggle] _UseCustomLight("Override light Color", Int) = 0
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
			uniform float4 _LitColor;
			uniform float4 _ShadowColor;
			uniform float4 _MainTex_ST;

			uniform sampler2D _NormalMap;
			uniform float _NormalStrength;

			uniform int _Posterize;

			half _DitherSize;
			int _UseCustomLight;

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

			float3 DitheredPalette(float x, float3 color1, float3 color2, float4 positionCS)
			{
				float idx = clamp(x, 0.0, 1.0) * int(_Posterize - 1);

				float DITHER_THRESHOLDS[16] =
				{
					1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
					13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
					4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
					16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
				};

				float2 uv = positionCS.xy / _ScreenParams.xy;
				uv *= _ScreenParams.xy * _DitherSize;
				uint index = (uint(uv.x) % 3) + uint(uv.y) % 3;
				// Returns > 0 if not clipped, < 0 if clipped based
				// on the dither
				//clip(alpha - DITHER_THRESHOLDS[index]);
				//clip(alpha - DITHER_THRESHOLDS[round(random(float2(_SinTime.y, _CosTime.y))* 16)]);

				//float3 color1 = Unity_Posterize_float3(lerp(_ShadowColor, _LitColor, idx / (_Posterize-1)),_Posterize);
				//float3 color2 = Unity_Posterize_float3(lerp(_ShadowColor, _LitColor, (idx + 1) / (_Posterize-1)),_Posterize);

				//return alpha;
				//float mixAmt = idx - 0.2 > DITHER_THRESHOLDS[index];
				float mixAmt = idx > DITHER_THRESHOLDS[index];
				//return lerp(_ShadowColor, _LitColor, mixAmt);
				return lerp(color1, color2, mixAmt);
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

				//LIGHTING_COORDS(5, 6)
				UNITY_LIGHTING_COORDS(5, 6)
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
				AlphaToMask On
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
					UNITY_LIGHT_ATTENUATION(attenuation, input, input.posWorld.xyz);
					if (0.0 == _WorldSpaceLightPos0.w) // directional light?
					{
						//attenuation = 1.0; // no attenuation
						lightDirection = normalize(_WorldSpaceLightPos0.xyz);
					}
					else // point or spot light
					{
						float3 vertexToLightSource =
							_WorldSpaceLightPos0.xyz - input.posWorld.xyz;
						float distance = length(vertexToLightSource);
						//attenuation = 1.0 / distance; // linear attenuation 
						lightDirection = normalize(vertexToLightSource);
					}

					//normalDirection = Unity_Posterize_float3(normalDirection, _Posterize);
					//lightDirection = Unity_Posterize_float3(lightDirection, _Posterize);

					float3 diffuseReflection = attenuation * _LightColor0.rgb * max(0.0, dot(normalDirection, lightDirection));
					//float3 specularReflection;

					//attenuation = LIGHT_ATTENUATION(input);

					float3 ambientLighting = UNITY_LIGHTMODEL_AMBIENT.rgb;

					float4 lightProbeLighting;
					lightProbeLighting.rgb = input.vLight;

					//half3 worldViewDir = normalize(UnityWorldSpaceViewDir(input.posWorld));
					//half3 reflection = reflect(-worldViewDir, normalDirection);

					float3 lightSum = ambientLighting + diffuseReflection + lightProbeLighting;
					float3 realCol = toGrayscale(lightSum);
					//col.rgb = col * lerp((ambientLighting + diffuseReflection + lightProbeLighting), 1, metallic);
					//col.rgb = lerp(col.rgb , skyColor * col.rgb, min(1, -(col.a - 1) + metallic + Smoothness * .07));
					//col.rgb = lerp(col.rgb, skyColor * 2, min(1, skyFresnel + 0.02) * Smoothness);

					//col.a = min(1, col.a + .1 * specularReflection);

					//realCol = Unity_Posterize_float3(realCol, _Posterize).rgb;

					float3 lightLerp = _UseCustomLight == 1 ? _LitColor : ambientLighting + input.vLightFlat + _LightColor0.rgb;

					//realCol = DitheredPalette(realCol.r, input.pos);
					//realCol = DitheredPalette(realCol.r,  _ShadowColor, _LitColor, input.pos);
					realCol = DitheredPalette(toGrayscale(realCol), _ShadowColor, lightLerp, input.pos);

					//realCol = lerp(_LitColor, _ShadowColor, realCol.r);
					//realCol = lerp(_ShadowColor, _LitColor,  realCol.r);

					////col.rgb = Unity_Posterize_float3(col.rgb, _Posterize);

					col.rgb *= realCol;


					return float4(col.rgb, col.a);

			}
			ENDCG
		}
		Pass
		{
			AlphaToMask On
			Cull[_Cull]
				//ZWrite[_ZWrite]
				//Ztest[_Ztest]		
				ZWrite On
				Ztest LEqual
				Tags
				{
					"LightMode" = "ForwardAdd"
					"VRCFallback" = "Toon"
					"Queue" = "Geometry"
				//"Queue" = "AlphaTest"
				"RenderType" = "Opaque"
				//"IgnoreProjector" = "False"
				//"RenderType" = "TransparentCutout"
			}
			Tags{"LightMode" = "ForwardAdd" "VRCFallback" = "Toon"}
			//Blend One One
			Blend SrcAlpha OneMinusSrcAlpha // use alpha blending
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdadd_fullshadows
				//#pragma target 3.0




				float4 frag(vertexOutput input) :SV_Target
				{
					float4 col = tex2D(_MainTex, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);

					float4 encodedNormal = tex2D(_NormalMap,input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
					//807fff
					encodedNormal = encodedNormal == (0, 0, 0, 1) ? (0.5, 0.5, 1, 0.5) : encodedNormal;
					encodedNormal = lerp(half4(0.5, 0.5, 0.5, .5), encodedNormal, _NormalStrength);


					float3 localCoords = float3(2.0 * encodedNormal.a - 1.0, 2.0 * encodedNormal.g - 1.0, 0.0);
					localCoords.z = sqrt(1.0 - dot(localCoords, localCoords));
					// approximation without sqrt:  localCoords.z = 
					// 1.0 - 0.5 * dot(localCoords, localCoords);

					float3x3 local2WorldTranspose = float3x3(input.tangentWorld, input.binormalWorld,input.normalWorld);
					float3 normalDirection = normalize(mul(localCoords, local2WorldTranspose));

					float3 viewDirection = normalize(_WorldSpaceCameraPos - input.posWorld.xyz);
					float3 lightDirection;

					float3 lightColor = _LightColor0;
					#ifdef USING_DIRECTIONAL_LIGHT
					//lightDirection = _WorldSpaceLightPos0;
					#else
					//lightDirection = _WorldSpaceLightPos0 - input.posWorld;
					#endif
					UNITY_LIGHT_ATTENUATION(attenuation, input, input.posWorld.xyz);
					//float3 color = lightColor * saturate(dot(lightDir, v.normalWorld) * attenuation);
					//float attenuation = 0.0;
					if (0.0 == _WorldSpaceLightPos0.w) // directional light?
					{
						//attenuation = 1.0; // no attenuation
						lightDirection = normalize(_WorldSpaceLightPos0.xyz);
					}
					else // point or spot light
					{
						float3 vertexToLightSource =
							_WorldSpaceLightPos0.xyz - input.posWorld.xyz;
						float distance = length(vertexToLightSource);
						//attenuation = 1.0 / distance; // linear attenuation 
						lightDirection = normalize(vertexToLightSource);
					}

					float3 diffuseReflection = attenuation * _LightColor0.rgb * max(0.0, dot(normalDirection, lightDirection));
					float3 realCol = toGrayscale(diffuseReflection);
					//col.rgb = col * lerp((ambientLighting + diffuseReflection + lightProbeLighting), 1, metallic);
					//col.rgb = lerp(col.rgb , skyColor * col.rgb, min(1, -(col.a - 1) + metallic + Smoothness * .07));
					//col.rgb = lerp(col.rgb, skyColor * 2, min(1, skyFresnel + 0.02) * Smoothness);

					//col.a = min(1, col.a + .1 * specularReflection);

					//realCol = Unity_Posterize_float3(realCol, _Posterize).rgb;

					float3 lightLerp = _UseCustomLight == 1 ? _LitColor : input.vLightFlat + _LightColor0.rgb;

					//realCol = DitheredPalette(realCol.r, input.pos);
					//realCol = DitheredPalette(realCol.r,  _ShadowColor, _LitColor, input.pos);
					realCol = DitheredPalette(toGrayscale(realCol), _ShadowColor, lightLerp, input.pos);

					//realCol = DitheredPalette(realCol.r, input.pos);
					//realCol = DitheredPalette(realCol.r, _ShadowColor, _LitColor, input.pos);

					col.rgb *= realCol;

					return float4(col.rgb, normalize(toGrayscale(realCol)));
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