Shader "LitBase"
{
	Properties
	{
		_MainTex("Main Texture", 2D) = "white" {}
		_TintColor("Tint Color", Color) = (1,1,1,1)
			//[Toggle] _UseNormal("Use Normal Map?", Int) = 0
			[NoScaleOffset] _NormalMap("Normal Map", 2D) = "bump" {} //for some reason, "bump" doesn't initialize properly, there is a fix for this down below
			_NormalStrength("Normal Strength", Range(0.0, 3.0)) = 1
			[NoScaleOffset] _MetallicMap("Metallic Map", 2D) = "black" {}
			_MetallicScale("Metallic scale", Range(0.0, 1.0)) = 0
			[NoScaleOffset] _RoughnessMap("Roughness Map", 2D) = "black" {}
			_RoughnessScale("Roughness scale", Range(0, 1)) = 1
			[Toggle] _UseEmission("Emission", Int) = 0
			[NoScaleOffset] _Emission("Emission Map", 2D) = "black" {}
			_EmissionColor("Emission Color", Color) = (1,1,1)
			_DiffColor("Diffuse Material Color", Color) = (1,1,1,1)
			_SpecColor("Specular Material Color", Color) = (1,1,1,1)
			_Specular("Specular Intensity", Range(0.0, 5.0)) = 1
			[HideInInspector][KeywordEnum(Opaque, Transparent, Custom)] _RenderPreset("Render Preset", Float) = 0
			[Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
			[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
			[Enum(Off, 0, On, 1)] _ZWrite("ZWrite", Int) = 1
			_AdjustMask("Color Adjustment mask", 2D) = "white" {}
			_Hue("Hue", Range(0,360)) = 0
			_Sat("Saturation", Range(0,10)) = 1
			_Bright("Brightness", Range(0, 100)) = 1
			_Opacity("Opacity", Range(0,1)) = 1
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
			uniform float4 _TintColor;
			uniform float4 _MainTex_ST;

			uniform sampler2D _NormalMap;
			uniform float _NormalStrength;

			uniform sampler2D _MetallicMap;
			uniform float _MetallicScale;

			uniform sampler2D _RoughnessMap;
			uniform float _RoughnessScale;

			uniform int _UseEmission;
			uniform sampler2D _Emission;
			uniform float3 _EmissionColor;


			uniform float4 _DiffColor;
			//uniform float4 _SpecColor;
			uniform float _Specular;

			uniform float _Opacity;
			uniform float _GlassOpacity;

			uniform sampler2D _AdjustMask;
			float _Hue;
			float _Sat;
			float _Bright;

			struct appdata
			{
				float4 vertex : POSITION;
				float4 texcoord : TEXCOORD0;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};
			struct v2f
			{
				float4 pos : SV_POSITION;
				float4 posWorld : TEXCOORD0;
				// position of the vertex (and fragment) in world space 
				float4 tex : TEXCOORD1;
				float3 tangentWorld : TEXCOORD2;
				float3 normalWorld : TEXCOORD3;
				float3 binormalWorld : TEXCOORD4;
				fixed3 vLight : COLOR;

				//LIGHTING_COORDS(5, 6)
				UNITY_LIGHTING_COORDS(5, 6)
				//V2F_SHADOW_CASTER
			};

			v2f vert(appdata input)
			{
				v2f output;

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
				return output;
			}

			float toGrayscale(float3 input)
			{
				return (input.r + input.g + input.b) / 3;
			}

			float3  rgb2hsv(float3 C)
			{
				saturate(C);
				float3 HSV = { 0,1,1 };
				float _min = C.r;
				float _med = C.g;
				float _max = C.b;
				float _t = 0;
				if (_min > _med)
				{
					_t = _min;
					_min = _med;
					_med = _t;
				}
				if (_min > _max)
				{
					_t = _min;
					_min = _max;
					_max = _t;
				}
				if (_med > _max)
				{
					_t = _med;
					_med = _max;
					_max = _t;
				}

				HSV.b = _max;

				float Delta = _max - _min;
				if (_max > 0)
				{
					HSV.g = Delta / _max;
				}

				if (Delta > 0)
				{
					if (_max == C.r) HSV.r = (C.g - C.b) / Delta;
					else if (_max == C.g) HSV.r = 2.0f + (C.b - C.r) / Delta;
					else      HSV.r = 4.0f + (C.r - C.g) / Delta;
				}
				HSV.r /= 6.0f;

				return HSV;
			}
			float3 hsv2rgb(float3 C)
			{
				float c = C.z * C.y;
				float x = c * (1 - abs((C.x * 6) % 2 - 1));
				float m = C.z - c;



				float3 CC = { 0,0,0 };
				switch (floor(C.r * 6))
				{
				case 0: CC = float3(c, x, 0); break;
				case 1: CC = float3(x, c, 0); break;
				case 2: CC = float3(0, c, x); break;
				case 3: CC = float3(0, x, c); break;
				case 4: CC = float3(x, 0, c); break;
				case 5: CC = float3(c, 0, x); break;
				}
				CC.rgb += m;
				return CC;
			}

			ENDCG
			CustomEditor "LitBaseEditor"
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

					float4 frag(v2f input) : COLOR
					{
						// in principle we have to normalize tangentWorld,
						// binormalWorld, and normalWorld again; however, the 
						// potential problems are small since we use this 
						// matrix only to compute "normalDirection", 
						// which we normalize anyways

	
						float4 col = tex2D(_MainTex, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
						float adjustMask = tex2D(_AdjustMask, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw).r;
						col *= _TintColor;
						//col.a = _Opacity;
						//col.a = (1 - tex.a) * (_TintColor.a * i.color.a * 2.0f);

						float3 adjustedCol = col.rgb;
						_Hue = (_Hue) / 360;
						_Hue += 1;
						adjustedCol = rgb2hsv(adjustedCol.rgb);
						adjustedCol.r += _Hue;
						adjustedCol.r %= 1;
						adjustedCol.rgb = hsv2rgb(adjustedCol.rgb);

						fixed lum = saturate(Luminance(adjustedCol.rgb));
						adjustedCol.rgb = lerp(adjustedCol.rgb, fixed3(lum, lum, lum), (1 - _Sat));

						adjustedCol.rgb *= _Bright;

						col.rgb = lerp(col.rgb, adjustedCol, adjustMask);

						//float colGrayscale = (col.r + col.g + col.b) / 3.0;
						float colGrayscale = toGrayscale(col);
						float colGrayscaleInverted = -(colGrayscale - 1);

						float4 encodedNormal = tex2D(_NormalMap,input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
						//807fff
						encodedNormal = encodedNormal == (0, 0, 0, 1) ? (0.5, 0.5, 1, 0.5) : encodedNormal;
						encodedNormal = lerp(half4(0.5, 0.5, 0.5, .5), encodedNormal, _NormalStrength);

						float3 metallic = tex2D(_MetallicMap, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
						metallic = lerp(metallic, 1, _MetallicScale);
						//metallic = lerp(half4(0.5, 0.5, 0.5, .5), metallic, _MetallicScale);

						float Roughness = tex2D(_RoughnessMap, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw).r;
						Roughness = lerp(Roughness, 1, _RoughnessScale);
						float Smoothness = -(Roughness - 1) + 0.00001;

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

						//attenuation = LIGHT_ATTENUATION(input);

						float3 ambientLighting = UNITY_LIGHTMODEL_AMBIENT.rgb * _DiffColor.rgb;

						float3 diffuseReflection = attenuation * _LightColor0.rgb * _DiffColor.rgb * max(0.0, dot(normalDirection, lightDirection));

						float3 specularReflection;
						if (dot(normalDirection, lightDirection) < 0.0)
							// light source on the wrong side?
						{
							specularReflection = float3(0.0, 0.0, 0.0);
							// no specular reflection
						}
						else // light source on the right side
						{

							specularReflection = Smoothness * pow(metallic * .4 + Smoothness,3) * _Specular * attenuation * _LightColor0.rgb * _SpecColor.rgb * pow(max(0.0, dot( reflect(-lightDirection, normalDirection), viewDirection)),(pow(Smoothness, 3) * 60) / (Roughness + .02));
						}

						float4 lightProbeLighting;
						lightProbeLighting.rgb = input.vLight;

						//half3 worldViewDir = normalize(UnityWorldSpaceViewDir(input.posWorld));
						//half3 reflection = reflect(-worldViewDir, normalDirection);

						half3 reflection = reflect(-viewDirection, normalDirection);
						half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflection, Roughness * 9); //UNITY_SAMPLE_TEXCUBE_LOD('cubemap', 'sample coordinate', 'map-map level')
						half3 skyColor = DecodeHDR(skyData, unity_SpecCube0_HDR); // This is done because the cubemap is stored HDR

						float skyFresnel = .7 * max(0, pow(1 - dot(viewDirection, normalDirection) * 1.4, 3));

						col.rgb = lerp(col.rgb + specularReflection, col.rgb + col.rgb * specularReflection * 12, metallic);

					
						//float3 realCol = col * lerp((ambientLighting + diffuseReflection + specularReflection + lightProbeLighting), .2 + toGrayscale(ambientLighting + lightProbeLighting) , metallic);
						col.rgb = col * lerp((ambientLighting + diffuseReflection + lightProbeLighting), 1, metallic);
						col.rgb = lerp(col.rgb , skyColor * col.rgb, min(1, -(col.a - 1) + metallic + Smoothness * .07));
						col.rgb = lerp(col.rgb, skyColor * 2, min(1, skyFresnel + 0.02) * Smoothness);

						col.a = min(1, col.a + .1 * specularReflection);
						//if (_UseEmission)
						//{
						//	float3 emission = tex2D(_Emission, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw).rgb * _EmissionColor;
						//	col.rgb += emission;
						//}
						if (_UseEmission)
						{
							float3 emis = tex2D(_Emission, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw).rgb * _EmissionColor;

							//float3 adjustedCol = col.rgb;
							adjustedCol = emis.rgb;
							//_Hue = (_Hue) / 360;
							//_Hue += 1;
							adjustedCol = rgb2hsv(adjustedCol.rgb);
							adjustedCol.r += _Hue;
							adjustedCol.r %= 1;
							adjustedCol.rgb = hsv2rgb(adjustedCol.rgb);

							lum = saturate(Luminance(adjustedCol.rgb));
							adjustedCol.rgb = lerp(adjustedCol.rgb, fixed3(lum, lum, lum), (1 - _Sat));

							adjustedCol.rgb *= _Bright;

							//emis.rgb = lerp(emis.rgb, adjustedCol, adjustMask);
							emis.rgb = adjustedCol;

							col.rgb += emis;
							//return float4(emis.rgb, 1);
						}

	return float4(col.rgb, col.a * _Opacity);

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
				Blend One One
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_fwdadd_fullshadows
					//#pragma target 3.0




					float4 frag(v2f input) :SV_Target
					{
						float4 col = tex2D(_MainTex, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
						float colGrayscale = (col.r + col.g + col.b) / 3.0;
						float colGrayscaleInverted = -(colGrayscale - 1);

						float4 encodedNormal = tex2D(_NormalMap,input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
						//807fff
						encodedNormal = encodedNormal == (0, 0, 0, 1) ? (0.5, 0.5, 1, 0.5) : encodedNormal;
						encodedNormal = lerp(half4(0.5, 0.5, 0.5, .5), encodedNormal, _NormalStrength);

						float Roughness = tex2D(_RoughnessMap, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw).r;
						Roughness = lerp(Roughness, 1, _RoughnessScale);
						float Smoothness = -(Roughness - 1) + 0.00001;

						float3 metallic = tex2D(_MetallicMap, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
						metallic = lerp(metallic, 1, _MetallicScale);

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

						float3 diffuseReflection = attenuation * _LightColor0.rgb * _DiffColor.rgb * max(0.0, dot(normalDirection, lightDirection));
						float3 specularReflection;
						if (dot(normalDirection, lightDirection) < 0.0)
							// light source on the wrong side?
						{
							specularReflection = float3(0.0, 0.0, 0.0);
							// no specular reflection
						}
						else // light source on the right side
						{

							specularReflection =  Smoothness * pow(metallic * .4 + Smoothness, 3) * _Specular * attenuation * _LightColor0.rgb
								* _SpecColor.rgb * pow(max(0.0, dot(
									reflect(-lightDirection, normalDirection),
									viewDirection)), (pow(Smoothness, 3) * 60) / (Roughness + .02));
						}

						half3 reflection = reflect(-viewDirection, normalDirection);
						//float Roughness = (-(_Shininess - 100)) / 100;
						half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflection, Roughness * 6); //UNITY_SAMPLE_TEXCUBE_LOD('cubemap', 'sample coordinate', 'map-map level')
						half3 skyColor = DecodeHDR(skyData, unity_SpecCube0_HDR); // This is done because the cubemap is stored HDR

						float skyFresnel = .7 * max(0, pow(1 - dot(viewDirection, normalDirection) * 1.4, 3));

						col.rgb = lerp(col.rgb * (diffuseReflection) + specularReflection, col.rgb * specularReflection * 20, metallic);

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