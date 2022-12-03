Shader "starVoid"
{

	Properties
	{
	    //_MainTex("Main Texture", 2D) = "black" {}
	    _AlphaMask("AlphaMask", 2D) = "white" {}

		_RimSize("Rim Size", Range(0, 4)) = 3.43
		_RimGradient("Rim Gradient", Range(0, 4)) = 1.38

		_Seed("RNG Seed", Range(0,3.1416)) = 0

		[Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
		[Enum(Off, 0, On, 1)] _ZWrite("ZWrite", Int) = 1


		//_Stars1("Stars1", Color) = (1, 1, 1, 1)
		//_Stars2("Stars2", Color) = (1, 1, 1, 1)
		//_Stars3("Stars3", Color) = (1, 1, 1, 1)

		_Quantize("Quantize", Range(1, 500)) = 10
	}

		CGINCLUDE //shared includes, variables, and functions
		#include "UnityCG.cginc"

		// User-specified properties
	    sampler2D _AlphaMask;

		uniform sampler2D _NormalMap;
		uniform float _NormalStrength;

		uniform float _Brightness;
		int _Quantize;
		float _WFactor;

		half _RimSize;
		half _RimGradient;

		//float4 _Stars1;
		//float4 _Stars2;
		//float4 _Stars3;
		uniform float _Seed;

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

		float Quantize(float num, float quantize)
		{
			return round(num * quantize) / quantize;
		}

		float4 Quantize4(float4 num, float quantize)
		{
			return round(num * quantize) / quantize;
		}

		float random(float2 seed)
		{
			return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453123);
		}

		float3 noise3d(float4 p) {
			p.w += frac(sin(dot(floor(p).xyz, float3(127.1, 311.7, 413.5))) * (43758.5453 + _Seed));
			float f = frac(p.w);
			float3 u = f * f * (3.0 - 2.0 * f);
			p.w = floor(p.w);
			float3 t1 = frac(sin(float3(dot(p, float4(127.1, 311.7, 413.5, 759.3)), dot(p, float4(269.5, 183.3, 197.7, 571.1)), dot(p, float4(975.1, 343.7, 435.3, 183.5)))) * (43758.5453 + _Seed));
			p.w += 1.0;
			float3 t2 = frac(sin(float3(dot(p, float4(127.1, 311.7, 413.5, 759.3)), dot(p, float4(269.5, 183.3, 197.7, 571.1)), dot(p, float4(975.1, 343.7, 435.3, 183.5)))) * (43758.5453 + _Seed));
			return t1 * (1.0 - u) + t2 * u;
		}


		float random4dLerp(in float4 st) {
			float4 rand4 = float4(12.9898, 78.233, 54.5913, 33.13467);

			float4 i = floor(st);
			float4 f = frac(st);
			return lerp(lerp(lerp(lerp(frac(sin(dot(i, rand4)) * (43758.5453 + _Seed)),
				frac(sin(dot(i + float4(1.0, 0.0, 0.0, 0.0), rand4)) * (43758.5453 + _Seed)),
				f.x),
				lerp(frac(sin(dot(i + float4(0.0, 1.0, 0.0, 0.0), rand4)) * (43758.5453 + _Seed)),
					frac(sin(dot(i + float4(1.0, 1.0, 0.0, 0.0), rand4)) * (43758.5453 + _Seed)),
					f.x),
				f.y),
				lerp(lerp(frac(sin(dot(i + float4(0.0, 0.0, 1.0, 0.0), rand4)) * (43758.5453 + _Seed)),
					frac(sin(dot(i + float4(1.0, 0.0, 1.0, 0.0), rand4)) * (43758.5453 + _Seed)),
					f.x),
					lerp(frac(sin(dot(i + float4(0.0, 1.0, 1.0, 0.0), rand4)) * (43758.5453 + _Seed)),
						frac(sin(dot(i + float4(1.0, 1.0, 1.0, 0.0), rand4)) * (43758.5453 + _Seed)),
						f.x),
					f.y),
				f.z),
				lerp(lerp(lerp(frac(sin(dot(i + float4(0.0, 0.0, 0.0, 1.0), rand4)) * (43758.5453 + _Seed)),
					frac(sin(dot(i + float4(1.0, 0.0, 0.0, 1.0), rand4)) * (43758.5453 + _Seed)),
					f.x),
					lerp(frac(sin(dot(i + float4(0.0, 1.0, 0.0, 1.0), rand4)) * (43758.5453 + _Seed)),
						frac(sin(dot(i + float4(1.0, 1.0, 0.0, 1.0), rand4)) * (43758.5453 + _Seed)),
						f.x),
					f.y),
					lerp(lerp(frac(sin(dot(i + float4(0.0, 0.0, 1.0, 1.0), rand4)) * (43758.5453 + _Seed)),
						frac(sin(dot(i + float4(1.0, 0.0, 1.0, 1.0), rand4)) * (43758.5453 + _Seed)),
						f.x),
						lerp(frac(sin(dot(i + float4(0.0, 1.0, 1.0, 1.0), rand4)) * (43758.5453 + _Seed)),
							frac(sin(dot(i + float4(1.0, 1.0, 1.0, 1.0), rand4)) * (43758.5453 + _Seed)),
							f.x),
						f.y),
					f.z),
				f.w);
		}

		float fbm(in float4 _st) {
			int num_octaves = 5;
			float v = 0.0;
			float a = 0.5;
			float2 shift = float2(100.0, 100.0);
			// Rotate to reduce axial bias
			float2x2 rot = float2x2(cos(0.5), sin(0.5),
				-sin(0.5), cos(0.5));
			for (int i = 0; i < num_octaves; ++i) {
				v += a * random4dLerp(_st);
				_st.xy = mul(rot, _st.xy) * 2.0 + shift;
				_st.yz = mul(rot, _st.yz) * 2.0 + shift;
				a *= 0.5;
			}
			return v;
		}

		float3 voronoi(float3 x) {
			float3 n = floor(x);
			float3 f = frac(x);



			//regular voronoi
			float3 col = float3(0, 0, 0);
			for (int x = -1; x <= 1; x++) {
				for (int y = -1; y <= 1; y++) {
					for (int z = -1; z <= 1; z++) {
						float3 g = float3(float(x), float(y), float(z));
						//float3 o = noise3d(float4(n + g, _Time.x * 5.));
						float3 o = noise3d(float4(n + g, 1 * 5.));

						float3 r = g + o - f;
						float v = length(o);
						//float3 tint = _Stars2;
						//float3 tint = float3(1,1,1);
						//float3 tint = float3(0,0,0);
						float3 tint = float3(1,1,1) * sin(_Time.y);
						//float3 tint = float3(1,1,1) * sin(_Time.y);
						float tintD = (normalize(o).x) * 2 - 1;

						//if (tintD < 0) {
						//	tint = _Stars1 * -tintD + tint * (1 + tintD);
						//}
						//else {
						//	tint = _Stars3 * tintD + tint * (1 - tintD);
						//}

						if (tintD < 0) {
							tint = -tintD + tint * (1 + tintD) * sin(_Time.y + 1.047);
							//tint = -tintD * (1 + tintD) * sin(_Time.y + 1.047);
							//tint = -tintD * (1 + tintD) * float3(1, 1, 1);
						}
						else {
							tint = tintD + tint * (1 - tintD) * sin(_Time.y + 2.094);
							//tint = tintD * (1 - tintD) * sin(_Time.y + 2.09);
						}

						r = 1.0 - length(r * 5.);
						float d = clamp(((r.x + r.y + r.z)) - 1. / (v * 2.), 0., 1.);
						col += float3(d, d, d) * tint;
					}
				}
			}
			return col * 8;
		}

	   ENDCG
	   SubShader
	   {
		  Tags
		  {
			  "Queue" = "Transparent"
			  "IgnoreProjector" = "True"
		      "VRCFallback" = "Toon"
		  }
		  Blend SrcAlpha OneMinusSrcAlpha // use alpha blending
		  Pass
		  {
			  AlphaToMask On
			  Cull[_Cull]
			  ZWrite[_ZWrite]
			  Ztest[_ZTest]

			  CGPROGRAM
			  #pragma vertex vert
			  #pragma fragment frag

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
				  float4 posObj : TEXCOORD1;
				  // position of the vertex (and fragment) in world space 
				  float4 tex : TEXCOORD2;
				  float3 tangentWorld : TEXCOORD3;
				  float3 normalWorld : TEXCOORD4;
				  float3 binormalWorld : TEXCOORD5;
				  //float4 normal : TEXCOORD6;
			  };
			  //CustomEditor "Scootoon_2Editor"
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

					//output.posWorld = mul(modelMatrix, input.vertex);
					output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
					output.tex = input.texcoord;
					output.pos = UnityObjectToClipPos(input.vertex);
					output.posObj = input.vertex;
					////float4 worldN = mul((float3x3)unity_ObjectToWorld, input.normal);
					////half3 worldN = mul((float3x3)unity_ObjectToWorld, float4(input.normal.x, input.normal.y, input.normal.z, 0.0));
					//half3 worldN = UnityObjectToWorldNormal(input.normal);
					//half3 shlight = ShadeSH9(float4(worldN, 1.0));

					return output;
			  }

			  float4 frag(vertexOutput input) : COLOR
			  {
				     //half4 col = tex2D(_MainTex, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
					 float4 quantizedPos = Quantize4(float4(input.posObj.x, input.posObj.y, input.posObj.z, _WFactor * input.posObj.w), _Quantize);
					 //float returnable = Quantize(noise3d(quantizedPos), _Quantize);
					 //return float4(returnable,returnable,returnable,1);
					 //return input.posObj;

					 //float4 encodedNormal = tex2D(_NormalMap, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);
					 float4 encodedNormal = float4(.5,.5,.5,.5);
					 //807fff
					 encodedNormal = encodedNormal == (0, 0, 0, 1) ? (0.5, 0.5, 1, 0.5) : encodedNormal;
					 //encodedNormal.rgb = saturate(lerp(half3(0.5, 0.5, 0.5), encodedNormal, _NormalStrength));
					 encodedNormal = lerp(half4(0.5, 0.5, 0.5, .5), encodedNormal, _NormalStrength);

					 float3 localCoords = float3(2.0 * encodedNormal.a - 1.0, 2.0 * encodedNormal.g - 1.0, 0.0);
					 //localCoords.z = sqrt(1.0 - dot(localCoords, localCoords));
					 // approximation without sqrt:  
					 localCoords.z = 1.0 - 0.5 * dot(localCoords, localCoords);

					 float3x3 local2WorldTranspose = float3x3(input.tangentWorld, input.binormalWorld, input.normalWorld);
					 float3 normalDirection = normalize(mul(localCoords, local2WorldTranspose));


					 float3 headDirection;

#if defined(USING_STEREO_MATRICES)
					 //float x = _XRWorldSpaceCameraPos[i](0).xyz
					 headDirection = normalize(unity_StereoWorldSpaceCameraPos[unity_StereoEyeIndex].xyz + unity_StereoWorldSpaceCameraPos[unity_StereoEyeIndex].xyz * 0.5) - input.posWorld;
#else
					 headDirection = normalize(UNITY_MATRIX_V._m20_m21_m22);
#endif
					 float3 viewDirection = normalize(_WorldSpaceCameraPos - input.posWorld.xyz);

					 float3 normalViewDirection = blendVRParallax(headDirection, viewDirection, 0.5);
					 //float3 bitangentViewDirection = UNITY_MATRIX_V._m10_m11_m12;
					 float3 bitangentViewDirection = float3(0, 1, 0);
					 bitangentViewDirection = orthoNormalize(bitangentViewDirection, normalViewDirection);

					 float3 tangentViewDirection = cross(normalViewDirection, bitangentViewDirection);

					 float3x3 tbnViewDirection = float3x3(tangentViewDirection, bitangentViewDirection, normalViewDirection);

					 //float2 matCapUV = mul(tbnViewDirection, input.normalWorld).xy;
					 float2 matCapUV = mul(tbnViewDirection, normalDirection).xy;
					 //matcapUV = lerp(matcapUV, input.tex * 2 - 1, 0);

					 //matCapUV = matCapUV * _MatCap_ST.xy + _MatCap_ST.zw;

					 matCapUV = matCapUV * 0.5 + 0.5;

					 //float sinx = fmod(sin((input.posObj.z + 1) * 1) * _Quantize, 4);
					 //float sinx = sin(input.posObj.x * _Quantize);
					 //float siny = sin(input.posObj.y * _Quantize);
					 //float sinz = sin(input.posObj.z * _Quantize);	
					 //float sinx = sin((input.posObj.x) * _Quantize);
					 //float siny = sin((input.posObj.y) * _Quantize);
					 //float sinz = sin((input.posObj.z) * _Quantize);

					 //float sinAvg = (sinx + siny + sinz) / 3;
					 //float3 returnable = voronoi(float3(sinx, siny, sinz));

					 float silhouette = min(1.0, .25 / abs(pow(dot(viewDirection, input.normalWorld) * _RimGradient, _RimSize)));
					 float3 col = voronoi(float3(matCapUV * input.posObj, 1) / silhouette * _Quantize);


					 //col = lerp(col, float3(0,0,0), silhouette);

					 //float returnable = silhouette;

					 //col = lerp(col.rgb, 0, silhouette);

					 //float3 returnable = voronoi(input.posObj * _Quantize);
					 //float4 MatCap = tex2D(_MainTex, matCapUV);
					 //return float4(returnable, returnable, returnable, 1);
					 float4 sampledAlphaMask = tex2D(_AlphaMask, input.tex);

					 return float4(col, sampledAlphaMask.a);
					 //return float4(scaledValue, scaledValue, scaledValue,1);
					 //return sampledAlphaMask;
					 //return MatCap;
			  }
			  ENDCG
		  }

	   }
}