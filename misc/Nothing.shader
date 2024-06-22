Shader "nothing"
{
	//invisibility shader
	//straight up invisible, no fancy effects
	//also has a fallback of VRChat/Mobile/Particles/Alpha Blended
	//the fallback is also transparent, because it has no texture

	Properties
	{

	}

		CGINCLUDE //shared includes, variables, and functions
		#include "UnityCG.cginc"

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
			  };
			  struct v2f
			  {
				  float4 pos : SV_POSITION;
			  };
			  //CustomEditor "Scootoon_2Editor"
			  v2f vert(appdata input)
			  {
					v2f output;
					output.pos = fixed4(0,0,0,0);

					return output;
			  }

			  float4 frag(v2f input) : COLOR
			  {
					discard;
					return fixed4(0, 0, 0, 0);
			  }
			  ENDCG
		  }

	   }
		Fallback "VRChat/Mobile/Particles/Alpha Blended"
}