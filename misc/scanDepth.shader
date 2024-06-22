Shader "scanDepth"
{

	//the true purpose of this shader has been lost to time
	//this line adjusts the blending mode to invert the colors behind it
	//when given a texture, it scrolls left and right according to the distance of the camera to the mesh (maybe that's why it's called scanDepth?)
	//blend srcalpha oneminussrcalpha

	Properties
	{
		_MainTex("Alpha mask", 2D) = "black" { }
		_Gradient("Depth color gradient right is farther, left is closer", 2D) = "black" { }
		_Brightness("Brightness", Range(0, 5)) = 1
		_Threshold("Threshold", Range(0, 1)) = 1

		[Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 0
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 1
		[Enum(Off, 0, On, 1)] _ZWrite("ZWrite", Int) = 1
	}

	CGINCLUDE //shared includes, variables, and functions
# include "UnityCG.cginc"

	// User-specified properties
	sampler2D _MainTex;
	sampler2D _Gradient;
	uniform float4 _MainTex_ST;
	uniform float _Brightness;
	uniform float _Threshold;


	ENDCG
	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque"
			"Queue" = "Geometry"
			"VRCFallback" = "Toon"
		}

		Pass
		{
			Cull[_Cull]
			ZWrite[_ZWrite]
			Ztest[_ZTest]
			AlphaToMask On
			blend srcalpha oneminussrcalpha
			CGPROGRAM
			#pragma vertex vert
#pragma fragment frag

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
				//float4 posWorld : TEXCOORD0;
				//float4 posObj : TEXCOORD1;
				// position of the vertex (and fragment) in world space 
				float4 tex : TEXCOORD2;
				//float3 tangentWorld : TEXCOORD3;
				//float3 normalWorld : TEXCOORD4;
				//float3 binormalWorld : TEXCOORD5;
			};
			//CustomEditor "Scootoon_2Editor"
			v2f vert(appdata input)
			{
				v2f output;

				//float4x4 modelMatrix = unity_ObjectToWorld;
				//float4x4 modelMatrixInverse = unity_WorldToObject;

				//output.tangentWorld = normalize(
				//	mul(modelMatrix, float4(input.tangent.xyz, 0.0)).xyz);
				//output.normalWorld = normalize(
				//	mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);
				//output.binormalWorld = normalize(
				//	cross(output.normalWorld, output.tangentWorld)
				//	* input.tangent.w); // tangent.w is specific to Unity

				////output.posWorld = mul(modelMatrix, input.vertex);
				//output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
				output.tex = input.texcoord;
				output.pos = UnityObjectToClipPos(input.vertex);
				//output.posObj = input.vertex;
				////float4 worldN = mul((float3x3)unity_ObjectToWorld, input.normal);
				////half3 worldN = mul((float3x3)unity_ObjectToWorld, float4(input.normal.x, input.normal.y, input.normal.z, 0.0));
				//half3 worldN = UnityObjectToWorldNormal(input.normal);
				//half3 shlight = ShadeSH9(float4(worldN, 1.0));

				return output;
			}

			float4 frag(v2f input) : COLOR
			{
				//half4 color = tex2D(_MainTex, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);

				float alpha = tex2D(_MainTex, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw).r;

				//float depth = 2 / (input.pos.z + input.pos.w);
				float depth = _Threshold * input.pos.w;

				float4 color = tex2D(_Gradient, float2(clamp(depth,.0001,.99), input.tex.y));

				color.a = alpha;

				return color * _Brightness;
			}
			ENDCG
		}

	}
}