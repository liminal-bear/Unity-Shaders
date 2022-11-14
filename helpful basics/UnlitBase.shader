Shader "UnlitBase"
{

	//the most basic shader, just a texture
	//other parameters for the shader are suppressed for now
	//you can make a copy of this code and use it as a starting point for more advanced shaders
	//to see what these parameters do, you can look at parameterView


        //shader properties, what will be seen in the inspector
	Properties
	{
	        _MainTex("Main Texture", 2D) = "black" {}
		_Brightness("Brightness", Range(0,5)) = 1
	}

		CGINCLUDE //shared includes, variables, and functions
		#include "UnityCG.cginc"

		// User-specified properties
                // These must be named exactly as how they were named in the properties
                // this is what connects the shader properties to the code
	        sampler2D _MainTex;
		uniform float _Brightness;

	   ENDCG
	   SubShader
	   {
                   //these are the shader tags, here, the shader is marked as
                   //transparent, with the fallback of toon if the shader is hidden
		  Tags
		  {
			  "Queue" = "Transparent"
			  "IgnoreProjector" = "True"
		      "VRCFallback" = "Toon"
		  }

                  //this defines one pass for this shader  
		  Pass
		  {
			  CGPROGRAM
                          //when this pass occurs, it will call vert, and frag
			  #pragma vertex vert
			  #pragma fragment frag
                          
                          //the vertexInput struct, also known as the 'appdata' struct
                          //this is the starting point for the vertex part of the shader
			  //it contains fundamental properties like the position, normal, and tangent of a vertex
                          //it also contains information of the UV map with texcoord
                          struct vertexInput
			  {
				  float4 vertex : POSITION;
				  float4 texcoord : TEXCOORD0;
				  float3 normal : NORMAL;
				  float4 tangent : TANGENT;
			  };

                          //after passing through 'vert', this is the struct that is then sent to frag
                          //it contains values like pos (clip space), posWorld, and posObj
                          //also has uvs, and more derived normal information
			  //mostly known a s 'v2f' struct, but renamed for clarity
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

			  //the vert (vertex) function
                          //Takes in a vertexInput, and returns a vertexOutput
                          //this is used best for modifying a vertex position, such as the model distortion in a hologram
                          //also used for passing data to the frag function
			  
			  vertexOutput vert(vertexInput input)
			  {
                                        //this is where we declare a vertexOuput struct, which we will return at the end
					vertexOutput output;

                                        //these properties are suppressed
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

                          //the frag (fragment, or, color function)
                          //once all information is processed in vert, the colors of the pixel is computed
			  float4 frag(vertexOutput input) : COLOR
			  {
                                         //this frag is quite simple, as we are just using an unlit texture
     				         //color is a float4, (red, green, blue, alpha)
                                         //tex2D is a function to sample a texture, at a uv coordinate, and return a float4
                                         float4 color = tex2D(_MainTex, input.tex.xy);
                                         //increases brightness by multiplying
					 return color * _Brightness;
			  }
			  ENDCG
		  }

	   }
}
