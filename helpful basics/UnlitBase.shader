Shader "UnlitBase"
{
	//the most basic shader, just a texture
	//other parameters for the shader are suppressed for now
	//you can make a copy of this code and use it as a starting point for more advanced shaders
	//to see what these parameters do, you can look at parameterView
	Properties
	{
		_MainTex("Main Texture", 2D) = "black" {}
		_Brightness("Brightness", Range(0,5)) = 1
		_Alpha("Alpha", Range(0, 1)) = 1

		[Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
		[Enum(Off, 0, On, 1)] _ZWrite("ZWrite", Int) = 1
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("BlendSource", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("BlendDestination", Float) = 6
	}

	CGINCLUDE //shared includes, variables, and functions
	#include "UnityCG.cginc"

	// User-specified properties
	sampler2D _MainTex;
	uniform float4 _MainTex_ST;
	uniform float _Brightness;
	uniform float _Alpha;


	ENDCG
	SubShader
	{
		Tags
		{
			//for a transparent shader, use {"Queue" = "Transparent" "RenderType"="Transparent" } 
			"RenderType" = "Opaque"
			"Queue" = "Geometry"
			"VRCFallback" = "Toon"
		}

		Pass
		{
			//face culling and depth buffer settings
			Cull[_Cull]
			ZWrite[_ZWrite]
			Ztest[_ZTest]

			//blend
			blend[_SrcBlend] [_DstBlend]

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
				//float4 posWorld : TEXCOORD0;
				//float4 posObj : TEXCOORD1;
				// position of the vertex (and fragment) in world space 
				float4 tex : TEXCOORD2;
				//float3 tangentWorld : TEXCOORD3;
				//float3 normalWorld : TEXCOORD4;
				//float3 binormalWorld : TEXCOORD5;
			};
			//CustomEditor "Scootoon_2Editor"
			vertexOutput vert(vertexInput input)
			{
					vertexOutput output;

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

			float4 frag(vertexOutput input) : COLOR
			{
					half4 color = tex2D(_MainTex, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);

					color.rgb *= _Brightness; //same as color.rgb = color.rgb * _Brightness
					color.a = _Alpha;
					return color;
			}
			ENDCG
		}

	}
}