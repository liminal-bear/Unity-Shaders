Shader "UnlitWorld"
{
	//the most basic shader, just a texture
	// 
	// modified to use world-space shading
	// 
	//other parameters for the shader are suppressed for now
	//you can make a copy of this code and use it as a starting point for more advanced shaders
	//to see what these parameters do, you can look at parameterView
	Properties
	{
		_MainTex("Main Texture", 2D) = "black" {}
		_Brightness("Brightness", Range(0,5)) = 1

		//[KeywordEnum(Opaque, Transparent, Custom)] _RenderPreset("Render Preset", Float) = 0
		[Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
		[Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
		[Enum(Off, 0, On, 1)] _ZWrite("ZWrite", Int) = 1
	}

	CGINCLUDE //shared includes, variables, and functions
	#include "UnityCG.cginc"

	// User-specified properties
	sampler2D _MainTex;
	uniform float4 _MainTex_ST;
	uniform float _Brightness;

	ENDCG
	SubShader
	{
		Tags
		{
			"Queue" = "Transparent"
			"IgnoreProjector" = "True"
			"VRCFallback" = "Toon"
		}

		Pass
		{
			Cull[_Cull]
			ZWrite[_ZWrite]
			Ztest[_ZTest]

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
				float4 posWorld : TEXCOORD0;
				//float4 posObj : TEXCOORD1;
				// position of the vertex (and fragment) in world space 
				float4 tex : TEXCOORD2;
				float3 tangentWorld : TEXCOORD3;
				float3 normalWorld : TEXCOORD4;
				//float3 binormalWorld : TEXCOORD5;
			};
			//CustomEditor "Scootoon_2Editor"
			v2f vert(appdata input)
			{
					v2f output;

					float4x4 modelMatrix = unity_ObjectToWorld;
					float4x4 modelMatrixInverse = unity_WorldToObject;

					output.tangentWorld = normalize(
						mul(modelMatrix, float4(input.tangent.xyz, 0.0)).xyz);
					output.normalWorld = normalize(
						mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);
					//output.binormalWorld = normalize(
					//	cross(output.normalWorld, output.tangentWorld)
					//	* input.tangent.w); // tangent.w is specific to Unity

					output.posWorld = mul(modelMatrix, input.vertex);
					//output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
					output.tex = input.texcoord;
					output.pos = UnityObjectToClipPos(input.vertex);
					//output.posObj = input.vertex;
					//float4 worldN = mul((float3x3)unity_ObjectToWorld, input.normal);
					half3 worldN = mul((float3x3)unity_ObjectToWorld, float4(input.normal.x, input.normal.y, input.normal.z, 0.0));
					//half3 worldN = UnityObjectToWorldNormal(input.normal);
					//half3 shlight = ShadeSH9(float4(worldN, 1.0));

					return output;
			}

			float4 frag(v2f input) : COLOR
			{
					//normal texturing uses an object's uv coordinate
					//half4 color = tex2D(_MainTex, input.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);

					//normal worldspace shading is like this, but it only looks good on the xy plane, so other orientations need to be considered with the code below
					//half4 color = tex2D(_MainTex, input.posWorld.xy * _MainTex_ST.xy + _MainTex_ST.zw);

					float3 projNormal = saturate(pow(input.normalWorld * 1.5, 4));
					float4 tangent = float4(0, 0, 0, 0);
					tangent.xyz = lerp(tangent.xyz, float3(0, 0, 1), projNormal.y);
					tangent.xyz = lerp(tangent.xyz, float3(0, 1, 0), projNormal.x);
					tangent.xyz = lerp(tangent.xyz, float3(1, 0, 0), projNormal.z);
					tangent.xyz = tangent.xyz - dot(tangent.xyz, input.normalWorld) * input.normalWorld;
					tangent.xyz = normalize(tangent.xyz);

					tangent.w = lerp(tangent.w, input.normalWorld.y, projNormal.y);
					tangent.w = lerp(tangent.w, -input.normalWorld.x, projNormal.x);
					tangent.w = lerp(tangent.w, input.normalWorld.z, projNormal.z);
					tangent.w = step(tangent.w, 0);
					tangent.w *= -2;
					tangent.w += 1;

					float3 binormal = cross(input.normalWorld, tangent.xyz) * tangent.w;
					float3x3 rotation = float3x3(tangent.xyz, binormal, input.normalWorld);

					// TEXTURE INPUTS USING WORLD POSITION BASED UVS
					//addad MainTex_ST for texture tiling and stretch
					half3 albedo0 = tex2D(_MainTex, input.posWorld.xy * _MainTex_ST.xy + _MainTex_ST.zw).rgb;
					half3 albedo1 = tex2D(_MainTex, input.posWorld.zx * _MainTex_ST.xy + _MainTex_ST.zw).rgb;
					half3 albedo2 = tex2D(_MainTex, input.posWorld.zy * _MainTex_ST.xy + _MainTex_ST.zw).rgb;

					// BLEND TEXTURE INPUTS BASED ON WORLD NORMAL
					float3 albedo;
					albedo = lerp(albedo1, albedo0, projNormal.z);
					albedo = lerp(albedo, albedo2, projNormal.x);

					return float4(albedo.rgb * _Brightness,1);
			}
			ENDCG
		}

	}
}