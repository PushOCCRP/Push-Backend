require "test_helper"

class WordpressTest < ActiveSupport::TestCase
  test "Clean up of Wordpress HTML entities should work" do
    input_text = '"body": "wp:paragraph --&gt;<br /><br /><strong>Svetlana Stojanović, sudija Osnovnog suda u<br /><br />Lazarevcu, osuđena je danas na pet godina zatvora jer je primila 2000 evra<br /><br />mita, saopštio je Viši sud u Beogradu. Stojanović je mito uzela od muškarca<br /><br />kome je sudila uz obećanje da ga neće osuditi na zatvorsku, već na uslovnu kaznu.</strong><br /><br />/wp:paragraph --&gt;<br /><br />wp:paragraph --&gt;<br /><br /><em>Piše: Milica Vojinović</em><br /><br />/wp:paragraph --&gt;<br /><br />wp:paragraph --&gt;<br /><br />Sudiji Stojanović, uz zatvorsku kaznu, izrečena<br /><br />je i petogodišnja zabrana obavljanja javne funkcije, tako da ona u tom periodu<br /><br />ne može da bude sudija. Osim nje, osuđen je i njen suprug Miroljub Stojanović na<br /><br />četiri i po godine zatvora jer je bio posrednik u uzimanju mita.<br /><br />/wp:paragraph --&gt;<br /><br />wp:paragraph --&gt;<br /><br />Presudu je izreklo veće Višeg suda u<br /><br />Beogradu na čelu sa sudijom Zoranom Trajković. Ona nije pravosnažna, jer<br /><br />osuđeni imaju pravo da se žale Apelacionom sudu u Beogradu.<br /><br />/wp:paragraph --&gt;<br /><br />wp:paragraph --&gt;<br /><br />Stojanović je, kako je utvrđeno, kao sudija<br /><br />u Osnovnom sudu u Lazarevcu uzela 2000 evra mita od Marinković Radiše kome je sudila<br /><br />za krijumčarenje ljudi.<br /><br />/wp:paragraph --&gt;<br /><br />wp:paragraph --&gt;<br /><br />Naime, sudijin suprug Miroljub pozvao je u<br /><br />oktobru 2018. godine Marinkovića da dođe u njihovu porodičnu kuću. Tokom sastanka<br /><br />sudija i suprug tražili su od Marinkovića 2000 evra. Sudija je obećala da će ga,<br /><br />ukoliko joj preda ovaj iznos, osuditi na uslovnu, a ne zatvorsku kaznu.<br /><br />/wp:paragraph --&gt;<br /><br />wp:paragraph --&gt;<br /><br />Marinković to nije učinio, pa ga je Stojanović<br /><br />osudila na godinu i po dana zatvora.<br /><br />/wp:paragraph --&gt;<br /><br />wp:paragraph --&gt;<br /><br />Bračni par Stojanović mu je, međutim, dao<br /><br />još jednu šansu, piše u optužnici, s obzirom da sudija u to vreme još nije<br /><br />napisala presudu i postupak nije bio gotov. Ponovo su tražili od Marinkovića 2000<br /><br />evra, kako bi ga spasili zatvora.<br /><br />/wp:paragraph --&gt;<br /><br />wp:paragraph --&gt;<br /><br />Sudija mu je objasnila da će napisati presudu<br /><br />„na koju će ljudi da se krste“, odnosno da će da napravi grešku zbog koje će viši<br /><br />sud da je ukine i da naloži novo suđenje. U ponovljenom postupku Stojanović će Marinkovića<br /><br />da osudi na uslovnu kaznu, piše u optužnici.<br /><br />/wp:paragraph --&gt;<br /><br />wp:paragraph --&gt;<br /><br />Ovaj put Marinković je pristao. Pre nego što<br /><br />je predao mito, međutim, kontaktirao je svog advokata i protiv sudije i njenog<br /><br />supruga podneo krivičnu prijavu, piše u optužnici. Potom je početkom novembra<br /><br />2018. novac odneo do porodične kuće Stojanovića i u dvorištu ga predao Miroljubu.<br /><br />/wp:paragraph --&gt;<br /><br />wp:paragraph --&gt;<br /><br />Istog dana policija je upala u kuću sudije i<br /><br />njenog supruga i pronašla kovertu sa 2000 evra, piše u optužnici Tužilaštva za<br /><br />organizovani kriminal.<br /><br />/wp:paragraph --&gt;<br /><br />wp:paragraph --&gt;<br /><br />Stojanovići su uhapšeni, a potom i optuženi u<br /><br />martu 2019. godine.<br /><br />/wp:paragraph --&gt;"'
    cleaned_input_text = Wordpress.handle_paragraph_tags input_text
    assert_match "wp:paragraph --&gt;", input_text
    assert_no_match "wp:paragraph --&gt;", cleaned_input_text
  end
end