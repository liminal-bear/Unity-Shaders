// jave.lin :  Reference resources ：https://medium.com/playkids-tech-blog/matcap-render-art-pipeline-optimization-for-mobile-devices-4e1a520b9f1a
//  It's too simple 
//  The principle is ： take   Convert normals to  ViewSpace, And then  ViewSpace  Normal under  [-1~1]  To  [0~1]
// also utilized matcap method used by lilToon shaders

Shader "MatCapHueShift"
{

	Properties
	{
		_MainTex("Diffuse (RGB)", 2D) = "white" {}
		_MatCap("MatCap (RGB)", 2D) = "gray" {}
		[NoScaleOffset] _NormalMap("Normal Map", 2D) = "bump" {} //for some reason, "bump" doesn't initialize properly, there is a fix for this down below
		_NormalStrength("Normal Strength", Range(0.0, 3.0)) = 1

		_TintColor("Tint Color", Color) = (1,1,1,1)

		_AdjustMask("Color Adjustment mask", 2D) = "white" {}
		_Hue("Hue", Range(0,360)) = 0
		_Sat("Saturation", Range(0,10)) = 1
		_Bright("Brightness", Range(0, 100)) = 1
		//_Opacity("Opacity", Range(0,1)) = 1

		[KeywordEnum(Opaque, Transparent, Custom)] _RenderPreset("Render Preset", Float) = 0
		[Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
		[Enum(Off, 0, On, 1)] _ZWrite("ZWrite", Int) = 1

		_Lerp("lerp texture", Float) = 2

		[MaterialToggle] _ColorCull("Color Cull", Int) = 0
		_CullThreshold("Threshold", Range(0,1)) = 1
		_ColorCulled("Color Culled", Color) = (0,0,0,0)

	}

	CGINCLUDE

	#include "UnityCG.cginc"
	#include "Lighting.cginc"
	#include "AutoLight.cginc"

	uniform sampler2D _MainTex;
	uniform float4 _TintColor;
	uniform sampler2D _MatCap;
	uniform float4 _MainTex_ST;
	uniform float4 _MatCap_ST;

	uniform sampler2D _NormalMap;
	uniform float _NormalStrength;

	uniform sampler2D _AdjustMask;
	float _Hue;
	float _Sat;
	float _Bright;
	float _Lerp;

	int _ColorCull;
	int _CullThreshold;
	uniform float4 _ColorCulled;

	float random(float2 seed)
	{
		return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453123);
	}

	float3 blendVRParallax(float3 a, float3 b, float c)
	{
#if defined(USING_STEREO_MATRICES)
		return lerp(a, b, c);
#else
		return b;
#endif
	}

	float3 orthoNormalize(float3 tangent, float3 normal)
	{
		return normalize(tangent - normal * dot(normal, tangent));
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

	float2 matcapSample(float3 viewDirection, float3 normalDirection)
	{
		half3 worldUp = float3(0, 1, 0);
		half3 worldViewUp = normalize(worldUp - viewDirection * dot(viewDirection, worldUp));
		half3 worldViewRight = normalize(cross(viewDirection, worldViewUp));
		half2 matcapUV = half2(dot(worldViewRight, normalDirection), dot(worldViewUp, normalDirection)) * 0.5 + 0.5;
		return matcapUV;
	}

//	float3 cameraDirection()
//	{
//#if defined(USING_STEREO_MATRICES)
//		return normalize(LIL_STEREO_MATRIX_V(0)._m20_m21_m22 + LIL_STEREO_MATRIX_V(1)._m20_m21_m22);
//#else
//		return UNITY_MATRIX_V._m20_m21_m22;
//#endif
	//}

	ENDCG
	SubShader
	{
		Tags { "RenderType" = "Opaque" "Queue" = "Geometry" }
		Pass
		{
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }

			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			#pragma multi_compile_fwdbase
			#pragma multi_compile_instancing
			#pragma skip_variants SHADOWS_SHADOWMASK SHADOWS_SCREEN SHADOWS_DEPTH SHADOWS_CUBE

			#include "UnityPBSLighting.cginc"
			#include "AutoLight.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 texcoord : TEXCOORD0;
				float3 normal : NORMAL;
				float4 color : COLOR;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 texcoord : TEXCOORD0;
				float4 worldPos : TEXCOORD1;
				float4 color : TEXCOORD2;
				float4 indirect : TEXCOORD3;
				float4 direct : TEXCOORD4;
				float3 normal : TEXCOORD5;
				SHADOW_COORDS(6)
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			//UNITY_DECLARE_TEX2D(_MainTex);
			//half4 _MainTex_ST;

			//UNITY_DECLARE_TEX2D(_MatCap);

			v2f vert(appdata input)
			{
				v2f output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_INITIALIZE_OUTPUT(v2f, output);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

				output.pos = UnityObjectToClipPos(input.vertex);
				output.worldPos = mul(unity_ObjectToWorld, input.vertex);
				output.texcoord = input.texcoord;

				half3 indirectDiffuse = ShadeSH9(float4(0, 0, 0, 1)); // We don't care about anything other than the color from GI, so only feed in 0,0,0, rather than the normal
				half4 lightCol = _LightColor0;

				//If we don't have a directional light or realtime light in the scene, we can derive light color from a slightly modified indirect color.
				int lightEnv = int(any(_WorldSpaceLightPos0.xyz));
				if (lightEnv != 1)
					lightCol = indirectDiffuse.xyzz * 0.2;

				float4 lighting = lightCol;

				output.color = input.color;
				output.direct = lighting;
				output.indirect = indirectDiffuse.xyzz;
				output.normal = input.normal


				TRANSFER_SHADOW(output);
				return output;
			}

			float4 frag(v2f input, float facing : VFACE) : SV_Target
			{
				float4 albedo = tex2D(_MainTex, TRANSFORM_TEX(input.texcoord, _MainTex));
				float adjustMask = tex2D(_AdjustMask, input.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw).r;
	
				float4 encodedNormal = tex2D(_NormalMap, input.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw);
				//807fff
				encodedNormal = encodedNormal == (0, 0, 0, 1) ? (0.5, 0.5, 1, 0.5) : encodedNormal;
				encodedNormal = lerp(half4(0.5, 0.5, 0.5, .5), encodedNormal, _NormalStrength);
				
				UNITY_LIGHT_ATTENUATION(attenuation, input, input.worldPos.xyz);

				float3 worldNorm = normalize(unity_WorldToObject[0].xyz * input.normal.x + unity_WorldToObject[1].xyz * input.normal.y + unity_WorldToObject[2].xyz * input.normal.z);
				worldNorm = mul((float3x3)UNITY_MATRIX_V, worldNorm);
				float2 matcapUV = matcapSample(normalize(_WorldSpaceCameraPos - input.worldPos), UnityObjectToWorldNormal(input.normal)); //worldNorm.xy * 0.5 + 0.5; 


				float4 mc = tex2D(_MatCap, matcapUV);
				float4 combined = (albedo * input.color * mc);

				float3 adjustedCol = combined.rgb;
				_Hue = (_Hue) / 360;
				_Hue += 1;
				adjustedCol = rgb2hsv(adjustedCol.rgb);
				adjustedCol.r += _Hue;
				adjustedCol.r %= 1;
				adjustedCol.rgb = hsv2rgb(adjustedCol.rgb);

				fixed lum = saturate(Luminance(adjustedCol.rgb));
				adjustedCol.rgb = lerp(adjustedCol.rgb, fixed3(lum, lum, lum), (1 - _Sat));

				adjustedCol.rgb *= _Bright;

				combined.rgb = lerp(combined.rgb, adjustedCol, adjustMask);

				//half4 final =  combined * (input.direct * attenuation + input.indirect);
				float rand = random(input.pos.z);
				float rand2 = random(input.pos.z + 0.000000000001 * input.pos.w);
				// clip((length(abs(combined.rgb - _ColorCulled.rgb)) < _CullThreshold) && _ColorCull ? -1 : 0);

				return float4(combined.rgb, 1);
			}
			ENDCG
		}
	}

		Fallback "VRChat/Mobile/Diffuse"
}