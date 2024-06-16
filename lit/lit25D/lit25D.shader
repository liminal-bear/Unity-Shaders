Shader "Lit25D"
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

			_Quantize("Quantize", Range(1, 360)) = 1
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

			int _Quantize;

			float Quantize(float num, float quantize)
			{
				return round(num * quantize) / quantize;
			}

			bool IsInMirror()
			{
				return unity_CameraProjection[2][0] != 0.f || unity_CameraProjection[2][1] != 0.f;
			}


			//float mod(float x, float y)
			//{
			//	return x - y * floor(x / y);
			//}

			float3 RotateAroundYInDegrees(float3 vertex, float degrees)
			{
				float alpha = degrees * UNITY_PI / 180.0;
				float sina, cosa;
				sincos(alpha, sina, cosa);
				float2x2 m = float2x2(cosa, -sina, sina, cosa);
				return float3(mul(m, vertex.xz), vertex.y).xzy;
			}			
			float3 RotateAroundYInRadians(float3 vertex, float radians)
			{
				float alpha = radians;
				float sina, cosa;
				sincos(alpha, sina, cosa);
				float2x2 m = float2x2(cosa, -sina, sina, cosa);
				return float3(mul(m, vertex.xz), vertex.y).xzy;
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
				float yawCameraCorrected : TEXCOORD5;
				fixed3 vLight : COLOR;

				//LIGHTING_COORDS(5, 6)
				UNITY_LIGHTING_COORDS(6, 7)
				//V2F_SHADOW_CASTER
				UNITY_FOG_COORDS(8)
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




				//output.posObj = input.vertex;
				//float3 vpos = mul((float3x3)unity_ObjectToWorld, input.vertex.xyz);
				//float3 vpos = mul((float3x3)unity_ObjectToWorld, flattenedVertex);
				//float4 worldCoord = float4(unity_ObjectToWorld._m03, unity_ObjectToWorld._m13, unity_ObjectToWorld._m23, 1);
				//float4 viewPos = mul(UNITY_MATRIX_V, worldCoord) + float4(vpos, 0);
				//float4 outPos = mul(UNITY_MATRIX_P, viewPos);


#if defined(USING_STEREO_MATRICES)
				float3 cameraPos = lerp(unity_StereoWorldSpaceCameraPos[0], unity_StereoWorldSpaceCameraPos[1], 0.5);
#else
				float3 cameraPos = _WorldSpaceCameraPos;
#endif
				//cameraPos = mul(UNITY_MATRIX_V, cameraPos);

				//cameraPos = input.vertex * cameraPos;

				//float3 cameraLocalPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0));

				//float3 viewDirection = normalize(_WorldSpaceCameraPos - output.posWorld.xyz);

				float3 forward = normalize(cameraPos - mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz);
				//float3 forward = normalize(cameraLocalPos - mul(unity_WorldToObject, float4(0, 0, 0, 1)).xyz);
				//float3 forward = normalize(cameraLocalPos - mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz);
				float3 right = cross(forward, float3(0, 1, 0));

				//float3 forward = viewDirection;
				//float yawCamera = atan2(right.x, forward.x) - UNITY_PI / 2;//Add 90 for quads to face towards camera
				float yawCamera = atan2(right.x, forward.x) - UNITY_PI / 2;//Add 90 for quads to face towards camera
				float s, c;

				sincos(yawCamera, s, c);

				float3 cameraLocalPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0));

				//float3 viewDirection = normalize(_WorldSpaceCameraPos - output.posWorld.xyz);

				//////float3 forward = normalize(cameraPos - mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz);
				//forward = normalize(cameraLocalPos - mul(unity_WorldToObject, float4(0, 0, 0, 1)).xyz);
				////float3 forward = normalize(cameraLocalPos - mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz);
				//right = cross(forward, float3(0, 1, 0));

				////float3 forward = viewDirection;
				//float3 right = cross(forward, float3(0, 1, 0));

				//forward = normalize(cameraLocalPos - mul(unity_WorldToObject, float4(0, 0, 0, 1)).xyz);
				//forward = normalize(cameraPos - mul(unity_WorldToObject, float4(0, 0, 0, 1)).xyz);
				//forward = normalize(cameraLocalPos - mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz);
				//forward = normalize(cameraPos - mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz);
				////float3 forward = normalize(cameraLocalPos - mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz);
				//right = cross(forward, float3(0, 1, 0));

				//float yawCameraCorrected = atan2(right.x, forward.x) - UNITY_PI / 2 + 0.261799;//Add 90 for quads to face towards camera, add extra 15 for correction value

				//0.261799 = 15 degrees to radians
				//float yawCameraCorrected = atan2(right.x, forward.x) - UNITY_PI / 2 + 0.261799;//Add 90 for quads to face towards camera, add extra 15 for correction value
				//float yawCameraCorrected = atan2(right.x, forward.x) + 0.261799;//Add 90 for quads to face towards camera

				//sincos(yawCameraCorrected - 0.261799, s, c);

				float3x3 transposed = transpose((float3x3)unity_ObjectToWorld);
				//float3x3 transposed = transpose((float3x3)unity_WorldToObject);
				float3 scale = float3(length(transposed[0]), length(transposed[1]), length(transposed[2]));

				float3x3 newBasis = float3x3(
					float3(c * scale.x, 0, s * scale.z),
					float3(0, scale.y, 0),
					float3(-s * scale.x, 0, c * scale.z)
					);//Rotate yaw to point towards camera, and scale by transform.scale

				float4x4 objectToWorld = unity_ObjectToWorld;
				//Overwrite basis vectors so the object rotation isn't taken into account
				objectToWorld[0].xyz = newBasis[0];
				objectToWorld[1].xyz = newBasis[1];
				objectToWorld[2].xyz = newBasis[2];

				//forward = normalize(cameraLocalPos - mul(objectToWorld, float4(0, 0, 0, 1)).xyz);
				////float3 forward = normalize(cameraLocalPos - mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz);
				//right = cross(forward, float3(0, 1, 0));

				//float yawCameraCorrected = atan2(right.x, forward.x) - UNITY_PI / 2 + 0.261799;//Add 90 for quads to face towards camera, add extra 15 for correction value

				float yawCameraCorrected = 0;

				float2 cameraObjDir = float2(0, 0);
				//UNITY_BRANCH if (IsInMirror())
				//{
				//	//cameraObjDir = mul((float3x3)unity_WorldToObject, mul((float3x3)unity_CameraToWorld, float3(0, 0, 1))).xz;
				//	cameraObjDir = mul((float3x3)unity_WorldToObject, unity_CameraWorldClipPlanes[5].xyz).xz;
				//}
				cameraObjDir = mul((float3x3)unity_WorldToObject, unity_CameraWorldClipPlanes[5].xyz).xz;


				//UNITY_BRANCH if (!IsInMirror())
				//{
				//	yawCameraCorrected = atan2(-cameraPos[0], -cameraPos[2]);
				//}
				//else
				//{
				//	yawCameraCorrected = atan2(cameraObjDir.x, cameraObjDir.y);
				//}

				yawCameraCorrected = atan2(cameraObjDir.x, cameraObjDir.y);

				//yawCameraCorrected = yawCameraCorrected + 0.785398;
				yawCameraCorrected = yawCameraCorrected + 0.261799;
				output.yawCameraCorrected = yawCameraCorrected;

				//0.785398 = 45 degrees to radians
				//float4 rotatedVertex = float4(RotateAroundYInRadians(input.vertex.xyz, 0.785398 * floor(yawCameraCorrected / 0.785398)), input.vertex.w);
				float4 rotatedVertex = float4(RotateAroundYInRadians(input.vertex.xyz, 0.785398 * floor(yawCameraCorrected / 0.785398)), input.vertex.w);
				//float4 rotatedVertex = float4(RotateAroundYInRadians(input.vertex.xyz, yawCameraCorrected), input.vertex.w);
				float4 flattenedVertex = float4(rotatedVertex.x, rotatedVertex.y, rotatedVertex.z * .05, rotatedVertex.w);
				//float4 flattenedVertex = float4(input.vertex.x, input.vertex.y, input.vertex.z * 0.005, input.vertex.w);
				output.pos = mul(UNITY_MATRIX_VP, mul(objectToWorld, flattenedVertex));
				//output.pos = mul(UNITY_MATRIX_VP, mul(objectToWorld, rotatedVertex));


				UNITY_TRANSFER_FOG(output, output.pos);

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
			CustomEditor "Lit25DEditor"
			SubShader
			{
				Tags
				{
					"LightMode" = "ForwardBase"
					"Queue" = "Geometry"
					"RenderType" = "Opaque"

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
					#pragma multi_compile_fog

					float4 frag(vertexOutput input) : COLOR
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

						//return float4(input.yawCameraCorrected, input.yawCameraCorrected, input.yawCameraCorrected, 1);

						//viewDirection = RotateAroundYInDegrees(viewDirection, 360 * 0.785398 * floor(input.yawCameraCorrected / 0.785398));
						//normalDirection = float3(Quantize(normalDirection.x,_Quantize), Quantize(normalDirection.y, _Quantize), Quantize(normalDirection.z, _Quantize));
						//normalDirection.xyz = RotateAroundYInDegrees(normalDirection, input.yawCameraCorrected);
						//normalDirection.x = RotateAroundYInDegrees(normalDirection, -360 * 0.785398 * floor(input.yawCameraCorrected / 0.785398)).x;
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

							specularReflection = Smoothness * pow(metallic * .4 + Smoothness,3) * _Specular * attenuation * _LightColor0.rgb
							* _SpecColor.rgb * pow(max(0.0, dot(
							reflect(-lightDirection, normalDirection),
							viewDirection)),(pow(Smoothness, 3) * 60) / (Roughness + .02));
						}

						float4 lightProbeLighting;
						lightProbeLighting.rgb = input.vLight;

						//half3 worldViewDir = normalize(UnityWorldSpaceViewDir(input.posWorld));
						//half3 reflection = reflect(-worldViewDir, normalDirection);

						//half3 reflection = reflect(-viewDirection, normalDirection);
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
						if (_UseEmission)
						{
							float3 emission = tex2D(_Emission, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw).rgb * _EmissionColor;

							//float3 adjustedCol = col.rgb;
							adjustedCol = emission.rgb;
							_Hue = (_Hue) / 360;
							_Hue += 1;
							adjustedCol = rgb2hsv(adjustedCol.rgb);
							adjustedCol.r += _Hue;
							adjustedCol.r %= 1;
							adjustedCol.rgb = hsv2rgb(adjustedCol.rgb);

							fixed lum = saturate(Luminance(adjustedCol.rgb));
							adjustedCol.rgb = lerp(adjustedCol.rgb, fixed3(lum, lum, lum), (1 - _Sat));

							adjustedCol.rgb *= _Bright;

							emission.rgb = lerp(col.rgb, adjustedCol, adjustMask);

							col.rgb += emission;
						}

						UNITY_APPLY_FOG(input.fogCoord, col);

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
					"RenderType" = "Opaque"
				}
				Tags{"LightMode" = "ForwardAdd" "VRCFallback" = "Toon"}
				Blend One One
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_fwdadd_fullshadows
					//#pragma target 3.0




					float4 frag(vertexOutput input) :SV_Target
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

						UNITY_APPLY_FOG(input.fogCoord, col);

						return float4(col.rgb, 1);
					}

					ENDCG
				}
				Pass
				{
					AlphaToMask On
					Tags {"LightMode" = "ShadowCaster"}
					CGPROGRAM
					#pragma vertex vertSShadow
					#pragma fragment fragSShadow
					float4 vertSShadow(float4 vertex : POSITION) : SV_POSITION{

						float4 clipPos = UnityObjectToClipPos(vertex.xyz);

						clipPos.z = lerp(clipPos.z,min(clipPos.z, clipPos.w * UNITY_NEAR_CLIP_VALUE), unity_LightShadowBias.y);
						return clipPos;
					}
					fixed4 fragSShadow(float4 pos : SV_POSITION) : SV_Target
					{
						clip(-1);
						return 0;
					}
					ENDCG
				}
			}
				Fallback "Diffuse"
}