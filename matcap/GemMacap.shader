// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

//uses matcap shading with hue/sat/bright sliders
//However, it uses a Geometry shader to change the normals to flat normals
//this can also be achieved with using ddx ddy (like normalFlats)

Shader "Ellioman/GeometryShader"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_MatCap("MatCap (RGB)", 2D) = "gray" {}
		//_Cube("Custom Cubemap for reflections", Cube) = "" {}
		//[NoScaleOffset] _RoughnessMap("Roughness Map", 2D) = "black" {}
		//_RoughnessScale("Roughness scale", Range(0, 1)) = 1

		_AdjustMask("Color Adjustment mask", 2D) = "white" {}
		_Hue("Hue", Range(0,360)) = 0
		_Sat("Saturation", Range(0,10)) = 1
		_Bright("Brightness", Range(0, 100)) = 1

	}
	CGINCLUDE

		// User Defined Variables
		uniform sampler2D _MainTex;
		uniform float4 _MainTex_ST;
		uniform sampler2D _MatCap;
		uniform float4 _MatCap_ST;
		uniform sampler2D _RoughnessMap;
		uniform float _RoughnessScale;
		//UNITY_DECLARE_TEXCUBE(_Cube);

		uniform sampler2D _AdjustMask;
		float _Hue;
		float _Sat;
		float _Bright;

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

	

		//sampler2D _GrabTexture;

	ENDCG


	SubShader
	{
		Tags
		{
			"RenderType"="Opaque"
		}
		LOD 100
		//
		//GrabPass
		//{
		//	"_GrabTexture"
		//}

		Pass
		{
			CGPROGRAM
			// Pragmas
			#pragma vertex vertexShader
			#pragma fragment fragmentShader
			#pragma geometry geometryShader
			
			// Helper functions
			#include "UnityCG.cginc"
			
	
			
			// Base Input Structs
			struct VSInput
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};
			
			struct VSOutput
			{
				float4 vertex : SV_POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
				float3 worldPosition : TEXCOORD1;
			};
			
			// The Vertex Shader 
			VSOutput vertexShader(VSInput input)
			{
				VSOutput output;
				output.vertex = UnityObjectToClipPos(input.vertex);
				output.uv = TRANSFORM_TEX(input.uv, _MainTex);
				output.normal = input.normal;
				output.worldPosition = mul(unity_ObjectToWorld, input.vertex).xyz;
				return output;
			}
			


			// The Geometry Shader
			[maxvertexcount(75)] // How many vertices can the shader output?
			void geometryShader(triangle VSOutput input[3], inout TriangleStream<VSOutput> OutputStream)
			{
				VSOutput output = (VSOutput) 0;
				float3 normal = normalize(cross(input[1].worldPosition.xyz - input[0].worldPosition.xyz, input[2].worldPosition.xyz - input[0].worldPosition.xyz));
				float4 curOffset = float4(0.0, 0.0, 0.0, 0.0);
				float4 curSize = float4(1.0, 1.0, 1.0, 1.0);
				
				//for(int k = 0; k < _Num; k++)
				//{
					for(int i = 0; i < 3; i++)
					{
						output.normal = normal;
						output.uv = input[i].uv;
						output.worldPosition = input[i].worldPosition.xyz;
						float4 a = float4((1 * input[i].worldPosition.xyz ), 1.0);
						a = mul(unity_WorldToObject, a);
						output.vertex = UnityObjectToClipPos(a);
						OutputStream.Append(output);
					}
					
					OutputStream.RestartStrip();
				//}
			}
			
			// The Fragment Shader
			fixed4 fragmentShader(VSOutput input) : SV_Target
			{
				// sample the texture
				fixed4 col = tex2D(_MainTex, input.uv);
				//float Roughness = tex2D(_RoughnessMap, input.uv.xy * _MainTex_ST.xy + _MainTex_ST.zw).r;
				//Roughness = lerp(Roughness, 1, _RoughnessScale);

				float adjustMask = tex2D(_AdjustMask, input.uv.xy * _MainTex_ST.xy + _MainTex_ST.zw).r;


				// Some Fake Lighting
				float3 lightDir = float3(-1, 1, -0.25);
				float ndotl = dot(input.normal, normalize(lightDir));
				
				//half4 cubeData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflection, Roughness * 9); //UNITY_SAMPLE_TEXCUBE_LOD('cubemap', 'sample coordinate', 'map-map level')
				//half3 cubeColor = DecodeHDR(cubeData, unity_SpecCube0_HDR); // This is done because the cubemap is stored HDR

				//float3 vNormalTs = UnpackScaleNormal(tex2D(_BumpMap, i.vTexCoord0.xy), 1);
				// Tangent space -> World space
				//float3 vNormalWs = Vec3TsToWsNormalized(vNormalTs.xyz, i.vNormalWs.xyz, i.vTangentUWs.xyz, i.vTangentVWs.xyz);


				float3 worldNorm = normalize(unity_WorldToObject[0].xyz * input.normal.x + unity_WorldToObject[1].xyz * input.normal.y + unity_WorldToObject[2].xyz * input.normal.z);
				worldNorm = mul((float3x3)UNITY_MATRIX_V, worldNorm);
				//return float4(input.normal, 1);

				float3 viewDirection = _WorldSpaceCameraPos - input.worldPosition.xyz;

				//half3 reflection = reflect(viewDirection, input.normal);
				//float Roughness = (-(_Shininess - 100)) / 100;
				//half4 cubeData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflection, Roughness * 6); //UNITY_SAMPLE_TEXCUBE_LOD('cubemap', 'sample coordinate', 'map-map level')
				//half4 cubeData = UNITY_SAMPLE_TEXCUBE_LOD(_Cube, reflection, Roughness * 6); //UNITY_SAMPLE_TEXCUBE_LOD('cubemap', 'sample coordinate', 'map-map level')
				//half3 cubeColor = DecodeHDR(cubeData, unity_SpecCube0_HDR); // This is done because the cubemap is stored HDR

				//return float4(cubeColor,1);
				float2 matcapUV = matcapSample(normalize(viewDirection), UnityObjectToWorldNormal(input.normal)); //worldNorm.xy * 0.5 + 0.5; 
				//float2 matcapUV = matcapSample(normalize(_WorldSpaceCameraPos - input.worldPosition.xyz), UnityObjectToWorldNormal(worldNorm.xyz * 0.5 + 0.5)); //worldNorm.xy * 0.5 + 0.5; 


				float4 mc = tex2D(_MatCap, matcapUV);
				float4 combined = (col * mc);

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

				//col.rgb *= cubeColor;
				//col *= ndotl;

				// Output
				return combined;
			}
			ENDCG
		}
	}
}