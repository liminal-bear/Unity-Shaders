Shader "Scootoon_1"
{
	Properties
	{
	   _MainTex("Main Texture", 2D) = "black" {}
	   _BumpMap("Normal Map", 2D) = "gray" {}
	   _Color("Diffuse Material Color", Color) = (1,1,1,1)
	   _SpecColor("Specular Material Color", Color) = (1,1,1,1)
	   _Shininess("Shininess", Float) = 10
	   _Quantize_Light("Quantize Lighting", Range(0,10)) = 1
	   _OutlineColor("Outline Color", Color) = (0,0,0,1)
	   _LitOutlineThickness("Lit Outline Thickness", Range(0,1)) = 0.1
	   _UnlitOutlineThickness("Unlit Outline Thickness", Range(0,1)) = 0.4
	}

	   CGINCLUDE //shared includes, variables, and functions
	   #include "UnityCG.cginc"
	   #include "AutoLight.cginc"
	   #include "Lighting.cginc"
	   //uniform float4 _LightColor0;
	   // color of light source (from "Lighting.cginc")

	   // User-specified properties
       sampler2D _MainTex;
	   uniform sampler2D _BumpMap;
	   uniform float4 _BumpMap_ST;
	   uniform float4 _Color;
	   uniform float _Shininess;

	   uniform float4 _OutlineColor;
	   uniform float _UnlitOutlineThickness;
	   uniform float _LitOutlineThickness;

	   int _Quantize_Light;

	   float random(float2 seed)
	   {
		   return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453123);
	   }
	   float Quantize(float num, float quantize)
	   {
		   return round(num * quantize) / quantize;
	   }

	   ENDCG
		   SubShader
	   {
		  Tags
		  {
			  "LightMode" = "ForwardBase"
			  "Queue" = "Transparent"
			  "IgnoreProjector" = "True"
			   "VRCFallback" = "Toon"
		  }

		  Pass
		  {
			  CGPROGRAM
			  #pragma vertex vert
			  #pragma fragment frag
			  #pragma multi_compile_fwdbase

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

				  LIGHTING_COORDS(5, 6)
					  //SHADOW_COORDS(7)
					  //unityShadowCoord4 _ShadowCoord : TEXCOORD7;
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

					 //output.posWorld = mul(modelMatrix, input.vertex);
					 output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
					 output.tex = input.texcoord;
					 output.pos = UnityObjectToClipPos(input.vertex);
					 //float4 worldN = mul((float3x3)unity_ObjectToWorld, input.normal);
					 //half3 worldN = mul((float3x3)unity_ObjectToWorld, float4(input.normal.x, input.normal.y, input.normal.z, 0.0));
					 half3 worldN = UnityObjectToWorldNormal(input.normal);
					 half3 shlight = ShadeSH9(float4(worldN, 1.0));
					 output.vLight = shlight;
					 TRANSFER_SHADOW(output);
					 TRANSFER_VERTEX_TO_FRAGMENT(output);

					 return output;
				 }

				 float4 frag(vertexOutput input) : COLOR
				 {
					 // in principle we have to normalize tangentWorld,
					 // binormalWorld, and normalWorld again; however, the 
					 // potential problems are small since we use this 
					 // matrix only to compute "normalDirection", 
					 // which we normalize anyways

					 float4 encodedNormal = tex2D(_BumpMap,
						_BumpMap_ST.xy * input.tex.xy + _BumpMap_ST.zw);
					 float3 localCoords = float3(2.0 * encodedNormal.a - 1.0,
						 2.0 * encodedNormal.g - 1.0, 0.0);
					 localCoords.z = sqrt(1.0 - dot(localCoords, localCoords));
					 // approximation without sqrt:  localCoords.z = 
					 // 1.0 - 0.5 * dot(localCoords, localCoords);

					 float3x3 local2WorldTranspose = float3x3(
						input.tangentWorld,
						input.binormalWorld,
						input.normalWorld);
					 float3 normalDirection =
						normalize(mul(localCoords, local2WorldTranspose));

					 float3 viewDirection = normalize(
						_WorldSpaceCameraPos - input.posWorld.xyz);
					 float3 lightDirection;
					 float attenuation = 0;
					 if (0.0 == _WorldSpaceLightPos0.w) // directional light?
					 {
						attenuation = 1.0; // no attenuation
						lightDirection = normalize(_WorldSpaceLightPos0.xyz);
					 }
					 else // point or spot light
					 {
						float3 vertexToLightSource =
						   _WorldSpaceLightPos0.xyz - input.posWorld.xyz;
						float distance = length(vertexToLightSource);
						attenuation = 1.0 / distance; // linear attenuation 
						lightDirection = normalize(vertexToLightSource);
					 }

					 //attenuation = LIGHT_ATTENUATION(input);

					 float3 ambientLighting =
						UNITY_LIGHTMODEL_AMBIENT.rgb * _Color.rgb;

					 float3 diffuseReflection =
						attenuation * _LightColor0.rgb * _Color.rgb
						* max(0.0, dot(normalDirection, lightDirection));

					 float3 specularReflection;
					 if (dot(normalDirection, lightDirection) < 0.0)
						 // light source on the wrong side?
					 {
						 specularReflection = float3(0.0, 0.0, 0.0);
						 // no specular reflection
					 }
					 else // light source on the right side
					 {
						 specularReflection = attenuation * _LightColor0.rgb
							* _SpecColor.rgb * pow(max(0.0, dot(
							reflect(-lightDirection, normalDirection),
							viewDirection)), _Shininess);
					 }

					 float4 lightProbeLighting;
					 lightProbeLighting.rgb = input.vLight;

					 float4 col = tex2D(_MainTex, input.tex.xy);

					 float3 realCol = col * Quantize((ambientLighting + diffuseReflection
						 + specularReflection + lightProbeLighting), _Quantize_Light);

					 //float3 Lightcol = Quantize(ambientLighting + diffuseReflection
						// + specularReflection + lightProbeLighting, _Quantize);

					 //better outline system, USE LATER
					 float skyFresnel = normalize(pow(dot(viewDirection, input.normalWorld), -23));

					 if (dot(viewDirection, normalDirection)
						 < lerp(_UnlitOutlineThickness, _LitOutlineThickness,
							 max(0.0, dot(normalDirection, lightDirection))))
					 {
						 float3 adjustCol = _LightColor0.rgb * _OutlineColor.rgb;
						 realCol *=  adjustCol;

					 }


					 //return float4(realCol, clamp(_Opacity +  * _Opacity, 0, 1));
					 return float4(realCol, 1);
					 //return float4(skyFresnel, skyFresnel, skyFresnel, 1);
					 //return col;
					 //return float4 (input.normalWorld, 1);
				 }
				 ENDCG
			 }
			 Pass
			 {
				  Tags{"LightMode" = "ForwardAdd" "VRCFallback" = "Toon"}
				  Blend One One
				  CGPROGRAM
				  #pragma vertex vert
				  #pragma fragment frag
				  #pragma multi_compile_fwdadd_fullshadows

				  #include "UnityCG.cginc"
				  #include "Lighting.cginc"
				  #include "AutoLight.cginc"
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

					 LIGHTING_COORDS(5, 6)
					 //unityShadowCoord4 _ShadowCoord : TEXCOORD7;
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

					 //output.posWorld = mul(modelMatrix, input.vertex);
					 output.posWorld = mul(UNITY_MATRIX_M, input.vertex);
					 output.tex = input.texcoord;
					 output.pos = UnityObjectToClipPos(input.vertex);
					 //float4 worldN = mul((float3x3)unity_ObjectToWorld, input.normal);
					 //half3 worldN = mul((float3x3)unity_ObjectToWorld, float4(input.normal.x, input.normal.y, input.normal.z, 0.0));
					 half3 worldN = UnityObjectToWorldNormal(input.normal);
					 half3 shlight = ShadeSH9(float4(worldN, 1.0));
					 output.vLight = shlight;
					 TRANSFER_SHADOW(output);
					 //TRANSFER_VERTEX_TO_FRAGMENT(output);

					 return output;
				 }

				 float4 frag(vertexOutput input) :SV_Target
				 {
					 float4 encodedNormal = tex2D(_BumpMap,
					 _BumpMap_ST.xy * input.tex.xy + _BumpMap_ST.zw);
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
					  lightDirection = _WorldSpaceLightPos0;
					 #else
					  lightDirection = _WorldSpaceLightPos0 - input.posWorld;
					 #endif
					 UNITY_LIGHT_ATTENUATION(attenuation, input, input.posWorld.xyz);
					 //float3 color = lightColor * saturate(dot(lightDir, v.normalWorld) * attenuation);
					 float3 diffuseReflection = attenuation * _LightColor0.rgb * _Color.rgb * max(0.0, dot(normalDirection, lightDirection));
					 float3 specularReflection;
					 if (dot(normalDirection, lightDirection) < 0.0)
						 // light source on the wrong side?
					 {
						 specularReflection = float3(0.0, 0.0, 0.0);
						 // no specular reflection
					 }
					 else // light source on the right side
					 {
						 specularReflection = attenuation * _LightColor0.rgb
							 * _SpecColor.rgb * pow(max(0.0, dot(
								 reflect(-lightDirection, normalDirection),
								 viewDirection)), _Shininess);
					 }
					 float4 col = tex2D(_MainTex, input.tex.xy);
					 float3 realCol = col * Quantize((diffuseReflection + specularReflection), _Quantize_Light);
					 //float3 realCol = col;
					 return float4(realCol, 1);
				 }

				 ENDCG
			 }


	   }
}