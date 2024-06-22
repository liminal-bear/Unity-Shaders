Shader "metallicReflections"
{
	//this shader shows how to sample reflection probes
	//this effect is mostly utilized in metals, such as in LitBase

	Properties
	{
	    _MainTex("Main Texture", 2D) = "black" {}
		_Roughness("Roughness", Range(0.0, 10.0)) = 0.0
	}

		CGINCLUDE //shared includes, variables, and functions
#include "UnityCG.cginc"


		// User-specified properties
	    sampler2D _MainTex;
		float _Roughness;


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
				  float4 posObj : TEXCOORD1;
				  // position of the vertex (and fragment) in world space 
				  float4 tex : TEXCOORD2;
				  //float3 tangentWorld : TEXCOORD3;
				  float3 normalWorld : TEXCOORD3;
				  //float3 binormalWorld : TEXCOORD5;
			  };
			  v2f vert(appdata input)
			  {
					v2f output;

					float4x4 modelMatrix = unity_ObjectToWorld;
					float4x4 modelMatrixInverse = unity_WorldToObject;

					//output.tangentWorld = normalize(
					//	mul(modelMatrix, float4(input.tangent.xyz, 0.0)).xyz);
					output.normalWorld = normalize(
						mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);
					//output.binormalWorld = normalize(
					//	cross(output.normalWorld, output.tangentWorld)
					//	* input.tangent.w); // tangent.w is specific to Unity

					//output.posWorld = mul(modelMatrix, input.vertex);
					output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
					output.tex = input.texcoord;
					output.pos = UnityObjectToClipPos(input.vertex);
					output.posObj = input.vertex;
					//float4 worldN = mul((float3x3)unity_ObjectToWorld, input.normal);
					//half3 worldN = mul((float3x3)unity_ObjectToWorld, float4(input.normal.x, input.normal.y, input.normal.z, 0.0));
					half3 worldN = UnityObjectToWorldNormal(input.normal);
					half3 shlight = ShadeSH9(float4(worldN, 1.0));

					return output;
			  }

			  float4 frag(v2f input) : COLOR
			  {
			         half3 worldViewDir = normalize(UnityWorldSpaceViewDir(input.posWorld)); //Direction of ray from the camera towards the object surface
					 half3 reflection = reflect(-worldViewDir, input.normalWorld); // Direction of ray after hitting the surface of object
					 /*If Roughness feature is not needed : UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, reflection) can be used instead.
					 It chooses the correct LOD value based on camera distance*/
					 half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflection, _Roughness); //UNITY_SAMPLE_TEXCUBE_LOD('cubemap', 'sample coordinate', 'map-map level')
					 half3 skyColor = DecodeHDR(skyData, unity_SpecCube0_HDR); // This is done because the cubemap is stored HDR

				     half3 col = tex2D(_MainTex, input.tex.xy);
					 col *= skyColor;

					 return float4(col , 1);
			  }
			  ENDCG
		  }

	   }
}