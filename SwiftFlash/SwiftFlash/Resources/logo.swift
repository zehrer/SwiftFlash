//
//  logo.swift
//  SwiftFlash
//
//  Created by Stephan Zehrer on 04.08.25.
//

import SwiftUI

struct IconShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.11388*width, y: 0.01181*height))
        path.addCurve(to: CGPoint(x: 0.03439*width, y: 0.0639*height), control1: CGPoint(x: 0.06351*width, y: 0.01158*height), control2: CGPoint(x: 0.03444*width, y: 0.03706*height))
        path.addCurve(to: CGPoint(x: 0.03439*width, y: 0.29299*height), control1: CGPoint(x: 0.03435*width, y: 0.09074*height), control2: CGPoint(x: 0.03441*width, y: 0.27113*height))
        path.addCurve(to: CGPoint(x: 0.05498*width, y: 0.30891*height), control1: CGPoint(x: 0.03418*width, y: 0.30873*height), control2: CGPoint(x: 0.03566*width, y: 0.30856*height))
        path.addCurve(to: CGPoint(x: 0.08001*width, y: 0.32802*height), control1: CGPoint(x: 0.0806*width, y: 0.30884*height), control2: CGPoint(x: 0.07966*width, y: 0.30794*height))
        path.addCurve(to: CGPoint(x: 0.08001*width, y: 0.41662*height), control1: CGPoint(x: 0.08011*width, y: 0.33334*height), control2: CGPoint(x: 0.07987*width, y: 0.39661*height))
        path.addCurve(to: CGPoint(x: 0.05169*width, y: 0.43571*height), control1: CGPoint(x: 0.08015*width, y: 0.43664*height), control2: CGPoint(x: 0.07421*width, y: 0.43599*height))
        path.addCurve(to: CGPoint(x: 0.03173*width, y: 0.45208*height), control1: CGPoint(x: 0.02917*width, y: 0.43543*height), control2: CGPoint(x: 0.03176*width, y: 0.44244*height))
        path.addCurve(to: CGPoint(x: 0.03869*width, y: 0.92916*height), control1: CGPoint(x: 0.03165*width, y: 0.47698*height), control2: CGPoint(x: 0.03835*width, y: 0.89201*height))
        path.addCurve(to: CGPoint(x: 0.10374*width, y: 0.98076*height), control1: CGPoint(x: 0.03903*width, y: 0.96631*height), control2: CGPoint(x: 0.041*width, y: 0.98094*height))
        path.addCurve(to: CGPoint(x: 0.8986*width, y: 0.97993*height), control1: CGPoint(x: 0.16649*width, y: 0.98057*height), control2: CGPoint(x: 0.84547*width, y: 0.98026*height))
        path.addCurve(to: CGPoint(x: 0.96474*width, y: 0.93329*height), control1: CGPoint(x: 0.95172*width, y: 0.9796*height), control2: CGPoint(x: 0.96331*width, y: 0.97888*height))
        path.addCurve(to: CGPoint(x: 0.9649*width, y: 0.44451*height), control1: CGPoint(x: 0.96617*width, y: 0.88771*height), control2: CGPoint(x: 0.96499*width, y: 0.45477*height))
        path.addCurve(to: CGPoint(x: 0.92461*width, y: 0.43037*height), control1: CGPoint(x: 0.9648*width, y: 0.43425*height), control2: CGPoint(x: 0.92504*width, y: 0.44381*height))
        path.addCurve(to: CGPoint(x: 0.92371*width, y: 0.36789*height), control1: CGPoint(x: 0.92418*width, y: 0.41692*height), control2: CGPoint(x: 0.92356*width, y: 0.3823*height))
        path.addCurve(to: CGPoint(x: 0.96474*width, y: 0.35277*height), control1: CGPoint(x: 0.92387*width, y: 0.35347*height), control2: CGPoint(x: 0.96479*width, y: 0.36097*height))
        path.addCurve(to: CGPoint(x: 0.96664*width, y: 0.21185*height), control1: CGPoint(x: 0.9647*width, y: 0.34458*height), control2: CGPoint(x: 0.9664*width, y: 0.22614*height))
        path.addCurve(to: CGPoint(x: 0.93294*width, y: 0.15788*height), control1: CGPoint(x: 0.96662*width, y: 0.18229*height), control2: CGPoint(x: 0.95331*width, y: 0.17212*height))
        path.addCurve(to: CGPoint(x: 0.78417*width, y: 0.0367*height), control1: CGPoint(x: 0.92319*width, y: 0.15107*height), control2: CGPoint(x: 0.82436*width, y: 0.06608*height))
        path.addCurve(to: CGPoint(x: 0.69886*width, y: 0.01024*height), control1: CGPoint(x: 0.74397*width, y: 0.00731*height), control2: CGPoint(x: 0.76254*width, y: 0.00922*height))
        path.addCurve(to: CGPoint(x: 0.11388*width, y: 0.01181*height), control1: CGPoint(x: 0.62595*width, y: 0.00942*height), control2: CGPoint(x: 0.13229*width, y: 0.01133*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.63963*width, y: 0.6954*height))
        path.addCurve(to: CGPoint(x: 0.62168*width, y: 0.69776*height), control1: CGPoint(x: 0.63401*width, y: 0.69599*height), control2: CGPoint(x: 0.62605*width, y: 0.69693*height))
        path.addCurve(to: CGPoint(x: 0.60062*width, y: 0.7039*height), control1: CGPoint(x: 0.61747*width, y: 0.69847*height), control2: CGPoint(x: 0.60796*width, y: 0.7013*height))
        path.addCurve(to: CGPoint(x: 0.57644*width, y: 0.71712*height), control1: CGPoint(x: 0.59048*width, y: 0.70767*height), control2: CGPoint(x: 0.58471*width, y: 0.71074*height))
        path.addCurve(to: CGPoint(x: 0.55975*width, y: 0.73377*height), control1: CGPoint(x: 0.56958*width, y: 0.72231*height), control2: CGPoint(x: 0.56334*width, y: 0.72869*height))
        path.addCurve(to: CGPoint(x: 0.55039*width, y: 0.75148*height), control1: CGPoint(x: 0.55663*width, y: 0.73825*height), control2: CGPoint(x: 0.55242*width, y: 0.74628*height))
        path.addCurve(to: CGPoint(x: 0.5468*width, y: 0.78512*height), control1: CGPoint(x: 0.54711*width, y: 0.75998*height), control2: CGPoint(x: 0.5468*width, y: 0.76328*height))
        path.addCurve(to: CGPoint(x: 0.54961*width, y: 0.817*height), control1: CGPoint(x: 0.5468*width, y: 0.80472*height), control2: CGPoint(x: 0.54727*width, y: 0.81074*height))
        path.addCurve(to: CGPoint(x: 0.55803*width, y: 0.83353*height), control1: CGPoint(x: 0.55117*width, y: 0.82125*height), control2: CGPoint(x: 0.55491*width, y: 0.82869*height))
        path.addCurve(to: CGPoint(x: 0.57629*width, y: 0.85195*height), control1: CGPoint(x: 0.56225*width, y: 0.84026*height), control2: CGPoint(x: 0.56661*width, y: 0.84475*height))
        path.addCurve(to: CGPoint(x: 0.60062*width, y: 0.86576*height), control1: CGPoint(x: 0.5858*width, y: 0.85915*height), control2: CGPoint(x: 0.59189*width, y: 0.86257*height))
        path.addCurve(to: CGPoint(x: 0.62168*width, y: 0.87202*height), control1: CGPoint(x: 0.60702*width, y: 0.86812*height), control2: CGPoint(x: 0.61654*width, y: 0.87096*height))
        path.addCurve(to: CGPoint(x: 0.64665*width, y: 0.8745*height), control1: CGPoint(x: 0.62683*width, y: 0.87296*height), control2: CGPoint(x: 0.63807*width, y: 0.87414*height))
        path.addCurve(to: CGPoint(x: 0.67629*width, y: 0.8732*height), control1: CGPoint(x: 0.65788*width, y: 0.87497*height), control2: CGPoint(x: 0.6663*width, y: 0.87462*height))
        path.addCurve(to: CGPoint(x: 0.70515*width, y: 0.86576*height), control1: CGPoint(x: 0.68596*width, y: 0.87178*height), control2: CGPoint(x: 0.69501*width, y: 0.86954*height))
        path.addCurve(to: CGPoint(x: 0.73089*width, y: 0.85195*height), control1: CGPoint(x: 0.717*width, y: 0.86139*height), control2: CGPoint(x: 0.72215*width, y: 0.85856*height))
        path.addCurve(to: CGPoint(x: 0.74758*width, y: 0.8353*height), control1: CGPoint(x: 0.73775*width, y: 0.84675*height), control2: CGPoint(x: 0.74399*width, y: 0.84038*height))
        path.addCurve(to: CGPoint(x: 0.75694*width, y: 0.81759*height), control1: CGPoint(x: 0.7507*width, y: 0.8307*height), control2: CGPoint(x: 0.75491*width, y: 0.82279*height))
        path.addCurve(to: CGPoint(x: 0.76053*width, y: 0.78512*height), control1: CGPoint(x: 0.76006*width, y: 0.80921*height), control2: CGPoint(x: 0.76053*width, y: 0.80555*height))
        path.addCurve(to: CGPoint(x: 0.75757*width, y: 0.75384*height), control1: CGPoint(x: 0.76053*width, y: 0.76635*height), control2: CGPoint(x: 0.76006*width, y: 0.76057*height))
        path.addCurve(to: CGPoint(x: 0.74961*width, y: 0.73731*height), control1: CGPoint(x: 0.75601*width, y: 0.74923*height), control2: CGPoint(x: 0.75242*width, y: 0.74179*height))
        path.addCurve(to: CGPoint(x: 0.73822*width, y: 0.72279*height), control1: CGPoint(x: 0.74696*width, y: 0.7327*height), control2: CGPoint(x: 0.74165*width, y: 0.72621*height))
        path.addCurve(to: CGPoint(x: 0.722*width, y: 0.71122*height), control1: CGPoint(x: 0.73463*width, y: 0.71948*height), control2: CGPoint(x: 0.7273*width, y: 0.71417*height))
        path.addCurve(to: CGPoint(x: 0.70281*width, y: 0.70248*height), control1: CGPoint(x: 0.71654*width, y: 0.70815*height), control2: CGPoint(x: 0.70796*width, y: 0.70425*height))
        path.addCurve(to: CGPoint(x: 0.68175*width, y: 0.6974*height), control1: CGPoint(x: 0.69766*width, y: 0.70071*height), control2: CGPoint(x: 0.68814*width, y: 0.69835*height))
        path.addCurve(to: CGPoint(x: 0.65991*width, y: 0.69504*height), control1: CGPoint(x: 0.67535*width, y: 0.69634*height), control2: CGPoint(x: 0.66552*width, y: 0.69528*height))
        path.addCurve(to: CGPoint(x: 0.63963*width, y: 0.6954*height), control1: CGPoint(x: 0.65429*width, y: 0.69469*height), control2: CGPoint(x: 0.64524*width, y: 0.69492*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.40484*width, y: 0.69622*height))
        path.addCurve(to: CGPoint(x: 0.3908*width, y: 0.69858*height), control1: CGPoint(x: 0.40234*width, y: 0.69646*height), control2: CGPoint(x: 0.39594*width, y: 0.69752*height))
        path.addCurve(to: CGPoint(x: 0.37207*width, y: 0.70401*height), control1: CGPoint(x: 0.38565*width, y: 0.69953*height), control2: CGPoint(x: 0.37722*width, y: 0.70201*height))
        path.addCurve(to: CGPoint(x: 0.35569*width, y: 0.71251*height), control1: CGPoint(x: 0.36693*width, y: 0.7059*height), control2: CGPoint(x: 0.35959*width, y: 0.7098*height))
        path.addCurve(to: CGPoint(x: 0.34399*width, y: 0.72503*height), control1: CGPoint(x: 0.35164*width, y: 0.71547*height), control2: CGPoint(x: 0.3468*width, y: 0.72066*height))
        path.addCurve(to: CGPoint(x: 0.33931*width, y: 0.74734*height), control1: CGPoint(x: 0.33963*width, y: 0.73223*height), control2: CGPoint(x: 0.33931*width, y: 0.73329*height))
        path.addCurve(to: CGPoint(x: 0.34275*width, y: 0.76741*height), control1: CGPoint(x: 0.33947*width, y: 0.75974*height), control2: CGPoint(x: 0.33994*width, y: 0.76293*height))
        path.addCurve(to: CGPoint(x: 0.35086*width, y: 0.77769*height), control1: CGPoint(x: 0.34446*width, y: 0.77037*height), control2: CGPoint(x: 0.34821*width, y: 0.77497*height))
        path.addCurve(to: CGPoint(x: 0.36552*width, y: 0.78749*height), control1: CGPoint(x: 0.35351*width, y: 0.78052*height), control2: CGPoint(x: 0.36006*width, y: 0.78489*height))
        path.addCurve(to: CGPoint(x: 0.38378*width, y: 0.79469*height), control1: CGPoint(x: 0.37083*width, y: 0.7902*height), control2: CGPoint(x: 0.3791*width, y: 0.79339*height))
        path.addCurve(to: CGPoint(x: 0.42012*width, y: 0.80236*height), control1: CGPoint(x: 0.38846*width, y: 0.7961*height), control2: CGPoint(x: 0.40484*width, y: 0.79953*height))
        path.addCurve(to: CGPoint(x: 0.45429*width, y: 0.80956*height), control1: CGPoint(x: 0.43526*width, y: 0.80519*height), control2: CGPoint(x: 0.4507*width, y: 0.8085*height))
        path.addCurve(to: CGPoint(x: 0.46443*width, y: 0.81488*height), control1: CGPoint(x: 0.45788*width, y: 0.81074*height), control2: CGPoint(x: 0.4624*width, y: 0.81311*height))
        path.addCurve(to: CGPoint(x: 0.46802*width, y: 0.82432*height), control1: CGPoint(x: 0.46724*width, y: 0.81747*height), control2: CGPoint(x: 0.46802*width, y: 0.8196*height))
        path.addCurve(to: CGPoint(x: 0.46505*width, y: 0.83412*height), control1: CGPoint(x: 0.46786*width, y: 0.82834*height), control2: CGPoint(x: 0.46693*width, y: 0.83188*height))
        path.addCurve(to: CGPoint(x: 0.45601*width, y: 0.84026*height), control1: CGPoint(x: 0.46334*width, y: 0.83601*height), control2: CGPoint(x: 0.45928*width, y: 0.83884*height))
        path.addCurve(to: CGPoint(x: 0.43838*width, y: 0.84416*height), control1: CGPoint(x: 0.45273*width, y: 0.84168*height), control2: CGPoint(x: 0.44477*width, y: 0.84345*height))
        path.addCurve(to: CGPoint(x: 0.41498*width, y: 0.84416*height), control1: CGPoint(x: 0.43042*width, y: 0.84498*height), control2: CGPoint(x: 0.42293*width, y: 0.84498*height))
        path.addCurve(to: CGPoint(x: 0.39672*width, y: 0.84002*height), control1: CGPoint(x: 0.40749*width, y: 0.84345*height), control2: CGPoint(x: 0.40094*width, y: 0.84191*height))
        path.addCurve(to: CGPoint(x: 0.38705*width, y: 0.83259*height), control1: CGPoint(x: 0.39267*width, y: 0.83825*height), control2: CGPoint(x: 0.38877*width, y: 0.8353*height))
        path.addCurve(to: CGPoint(x: 0.38315*width, y: 0.82432*height), control1: CGPoint(x: 0.38549*width, y: 0.83022*height), control2: CGPoint(x: 0.38378*width, y: 0.82645*height))
        path.addLine(to: CGPoint(x: 0.38222*width, y: 0.82054*height))
        path.addCurve(to: CGPoint(x: 0.33385*width, y: 0.82314*height), control1: CGPoint(x: 0.33401*width, y: 0.82054*height), control2: CGPoint(x: 0.33385*width, y: 0.82054*height))
        path.addCurve(to: CGPoint(x: 0.33619*width, y: 0.83259*height), control1: CGPoint(x: 0.33385*width, y: 0.82468*height), control2: CGPoint(x: 0.33495*width, y: 0.82893*height))
        path.addCurve(to: CGPoint(x: 0.34228*width, y: 0.84498*height), control1: CGPoint(x: 0.33744*width, y: 0.83636*height), control2: CGPoint(x: 0.34025*width, y: 0.84191*height))
        path.addCurve(to: CGPoint(x: 0.35476*width, y: 0.85679*height), control1: CGPoint(x: 0.34431*width, y: 0.84817*height), control2: CGPoint(x: 0.34992*width, y: 0.85348*height))
        path.addCurve(to: CGPoint(x: 0.37332*width, y: 0.86659*height), control1: CGPoint(x: 0.35959*width, y: 0.86021*height), control2: CGPoint(x: 0.36786*width, y: 0.86458*height))
        path.addCurve(to: CGPoint(x: 0.39314*width, y: 0.87214*height), control1: CGPoint(x: 0.37863*width, y: 0.86848*height), control2: CGPoint(x: 0.38752*width, y: 0.87096*height))
        path.addCurve(to: CGPoint(x: 0.42512*width, y: 0.87414*height), control1: CGPoint(x: 0.40062*width, y: 0.87367*height), control2: CGPoint(x: 0.40889*width, y: 0.87414*height))
        path.addCurve(to: CGPoint(x: 0.45866*width, y: 0.87202*height), control1: CGPoint(x: 0.43963*width, y: 0.87403*height), control2: CGPoint(x: 0.45086*width, y: 0.87332*height))
        path.addCurve(to: CGPoint(x: 0.47972*width, y: 0.86682*height), control1: CGPoint(x: 0.46505*width, y: 0.87096*height), control2: CGPoint(x: 0.47457*width, y: 0.8686*height))
        path.addCurve(to: CGPoint(x: 0.4961*width, y: 0.85868*height), control1: CGPoint(x: 0.48487*width, y: 0.86494*height), control2: CGPoint(x: 0.4922*width, y: 0.86139*height))
        path.addCurve(to: CGPoint(x: 0.50733*width, y: 0.84817*height), control1: CGPoint(x: 0.5*width, y: 0.85608*height), control2: CGPoint(x: 0.50499*width, y: 0.85136*height))
        path.addCurve(to: CGPoint(x: 0.51404*width, y: 0.8353*height), control1: CGPoint(x: 0.50952*width, y: 0.84498*height), control2: CGPoint(x: 0.51264*width, y: 0.8392*height))
        path.addCurve(to: CGPoint(x: 0.51607*width, y: 0.817*height), control1: CGPoint(x: 0.51607*width, y: 0.83011*height), control2: CGPoint(x: 0.51654*width, y: 0.82527*height))
        path.addCurve(to: CGPoint(x: 0.51154*width, y: 0.79929*height), control1: CGPoint(x: 0.5156*width, y: 0.80826*height), control2: CGPoint(x: 0.51466*width, y: 0.80437*height))
        path.addCurve(to: CGPoint(x: 0.5014*width, y: 0.78819*height), control1: CGPoint(x: 0.50936*width, y: 0.79575*height), control2: CGPoint(x: 0.50484*width, y: 0.79067*height))
        path.addCurve(to: CGPoint(x: 0.4844*width, y: 0.77969*height), control1: CGPoint(x: 0.49813*width, y: 0.78571*height), control2: CGPoint(x: 0.49048*width, y: 0.78182*height))
        path.addCurve(to: CGPoint(x: 0.44041*width, y: 0.76919*height), control1: CGPoint(x: 0.47816*width, y: 0.77745*height), control2: CGPoint(x: 0.45928*width, y: 0.77296*height))
        path.addCurve(to: CGPoint(x: 0.39984*width, y: 0.75986*height), control1: CGPoint(x: 0.42215*width, y: 0.76564*height), control2: CGPoint(x: 0.4039*width, y: 0.76139*height))
        path.addCurve(to: CGPoint(x: 0.38877*width, y: 0.75372*height), control1: CGPoint(x: 0.39563*width, y: 0.75844*height), control2: CGPoint(x: 0.3908*width, y: 0.75561*height))
        path.addCurve(to: CGPoint(x: 0.38534*width, y: 0.74581*height), control1: CGPoint(x: 0.38643*width, y: 0.75148*height), control2: CGPoint(x: 0.38518*width, y: 0.74876*height))
        path.addCurve(to: CGPoint(x: 0.38705*width, y: 0.73872*height), control1: CGPoint(x: 0.38534*width, y: 0.74345*height), control2: CGPoint(x: 0.38612*width, y: 0.74026*height))
        path.addCurve(to: CGPoint(x: 0.39298*width, y: 0.73282*height), control1: CGPoint(x: 0.38799*width, y: 0.73731*height), control2: CGPoint(x: 0.39064*width, y: 0.73471*height))
        path.addCurve(to: CGPoint(x: 0.40484*width, y: 0.72763*height), control1: CGPoint(x: 0.39516*width, y: 0.73105*height), control2: CGPoint(x: 0.40062*width, y: 0.72869*height))
        path.addCurve(to: CGPoint(x: 0.4259*width, y: 0.72562*height), control1: CGPoint(x: 0.40967*width, y: 0.72633*height), control2: CGPoint(x: 0.41763*width, y: 0.72562*height))
        path.addCurve(to: CGPoint(x: 0.44852*width, y: 0.72904*height), control1: CGPoint(x: 0.43744*width, y: 0.72562*height), control2: CGPoint(x: 0.44041*width, y: 0.72597*height))
        path.addCurve(to: CGPoint(x: 0.46256*width, y: 0.73991*height), control1: CGPoint(x: 0.45694*width, y: 0.73223*height), control2: CGPoint(x: 0.45835*width, y: 0.73329*height))
        path.addLine(to: CGPoint(x: 0.46724*width, y: 0.74723*height))
        path.addCurve(to: CGPoint(x: 0.51326*width, y: 0.74522*height), control1: CGPoint(x: 0.51108*width, y: 0.74734*height), control2: CGPoint(x: 0.51326*width, y: 0.74711*height))
        path.addCurve(to: CGPoint(x: 0.51076*width, y: 0.73613*height), control1: CGPoint(x: 0.51326*width, y: 0.74416*height), control2: CGPoint(x: 0.51217*width, y: 0.74002*height))
        path.addCurve(to: CGPoint(x: 0.50343*width, y: 0.72208*height), control1: CGPoint(x: 0.50952*width, y: 0.73223*height), control2: CGPoint(x: 0.50608*width, y: 0.72597*height))
        path.addCurve(to: CGPoint(x: 0.49142*width, y: 0.71039*height), control1: CGPoint(x: 0.50062*width, y: 0.7183*height), control2: CGPoint(x: 0.49532*width, y: 0.71299*height))
        path.addCurve(to: CGPoint(x: 0.47504*width, y: 0.70224*height), control1: CGPoint(x: 0.48752*width, y: 0.70767*height), control2: CGPoint(x: 0.48019*width, y: 0.70401*height))
        path.addCurve(to: CGPoint(x: 0.45476*width, y: 0.69717*height), control1: CGPoint(x: 0.46989*width, y: 0.70047*height), control2: CGPoint(x: 0.46084*width, y: 0.69811*height))
        path.addCurve(to: CGPoint(x: 0.42668*width, y: 0.69563*height), control1: CGPoint(x: 0.44836*width, y: 0.6961*height), control2: CGPoint(x: 0.43682*width, y: 0.69551*height))
        path.addCurve(to: CGPoint(x: 0.40484*width, y: 0.69622*height), control1: CGPoint(x: 0.41716*width, y: 0.69563*height), control2: CGPoint(x: 0.40733*width, y: 0.69599*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.2585*width, y: 0.69858*height))
        path.addLine(to: CGPoint(x: 0.24961*width, y: 0.69894*height))
        path.addLine(to: CGPoint(x: 0.25039*width, y: 0.86954*height))
        path.addCurve(to: CGPoint(x: 0.2922*width, y: 0.86907*height), control1: CGPoint(x: 0.27941*width, y: 0.86919*height), control2: CGPoint(x: 0.2897*width, y: 0.86907*height))
        path.addLine(to: CGPoint(x: 0.29641*width, y: 0.86895*height))
        path.addLine(to: CGPoint(x: 0.29641*width, y: 0.69894*height))
        path.addCurve(to: CGPoint(x: 0.2585*width, y: 0.69858*height), control1: CGPoint(x: 0.2741*width, y: 0.69847*height), control2: CGPoint(x: 0.26349*width, y: 0.69847*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.63417*width, y: 0.72893*height))
        path.addCurve(to: CGPoint(x: 0.62246*width, y: 0.73282*height), control1: CGPoint(x: 0.63073*width, y: 0.72963*height), control2: CGPoint(x: 0.62543*width, y: 0.7314*height))
        path.addCurve(to: CGPoint(x: 0.61092*width, y: 0.74038*height), control1: CGPoint(x: 0.6195*width, y: 0.73424*height), control2: CGPoint(x: 0.6142*width, y: 0.73766*height))
        path.addCurve(to: CGPoint(x: 0.60125*width, y: 0.75148*height), control1: CGPoint(x: 0.60749*width, y: 0.74321*height), control2: CGPoint(x: 0.60312*width, y: 0.74817*height))
        path.addCurve(to: CGPoint(x: 0.59626*width, y: 0.76328*height), control1: CGPoint(x: 0.59938*width, y: 0.75466*height), control2: CGPoint(x: 0.59719*width, y: 0.75998*height))
        path.addCurve(to: CGPoint(x: 0.5936*width, y: 0.77922*height), control1: CGPoint(x: 0.59532*width, y: 0.76647*height), control2: CGPoint(x: 0.59407*width, y: 0.77367*height))
        path.addCurve(to: CGPoint(x: 0.59423*width, y: 0.7987*height), control1: CGPoint(x: 0.59298*width, y: 0.78501*height), control2: CGPoint(x: 0.59329*width, y: 0.79327*height))
        path.addCurve(to: CGPoint(x: 0.59938*width, y: 0.81582*height), control1: CGPoint(x: 0.59516*width, y: 0.8039*height), control2: CGPoint(x: 0.5975*width, y: 0.81157*height))
        path.addCurve(to: CGPoint(x: 0.61217*width, y: 0.8307*height), control1: CGPoint(x: 0.60203*width, y: 0.82196*height), control2: CGPoint(x: 0.60452*width, y: 0.82491*height))
        path.addCurve(to: CGPoint(x: 0.63339*width, y: 0.84061*height), control1: CGPoint(x: 0.62059*width, y: 0.83707*height), control2: CGPoint(x: 0.62309*width, y: 0.83825*height))
        path.addCurve(to: CGPoint(x: 0.65757*width, y: 0.84274*height), control1: CGPoint(x: 0.64275*width, y: 0.84274*height), control2: CGPoint(x: 0.64758*width, y: 0.84321*height))
        path.addCurve(to: CGPoint(x: 0.67863*width, y: 0.83932*height), control1: CGPoint(x: 0.66646*width, y: 0.84239*height), control2: CGPoint(x: 0.67254*width, y: 0.84132*height))
        path.addCurve(to: CGPoint(x: 0.69345*width, y: 0.83211*height), control1: CGPoint(x: 0.68331*width, y: 0.83766*height), control2: CGPoint(x: 0.69002*width, y: 0.83447*height))
        path.addCurve(to: CGPoint(x: 0.7039*width, y: 0.8222*height), control1: CGPoint(x: 0.69688*width, y: 0.82987*height), control2: CGPoint(x: 0.70156*width, y: 0.82538*height))
        path.addCurve(to: CGPoint(x: 0.71045*width, y: 0.80874*height), control1: CGPoint(x: 0.70624*width, y: 0.81901*height), control2: CGPoint(x: 0.7092*width, y: 0.81299*height))
        path.addCurve(to: CGPoint(x: 0.71295*width, y: 0.7863*height), control1: CGPoint(x: 0.71201*width, y: 0.8039*height), control2: CGPoint(x: 0.71295*width, y: 0.79551*height))
        path.addCurve(to: CGPoint(x: 0.71076*width, y: 0.76387*height), control1: CGPoint(x: 0.71295*width, y: 0.77816*height), control2: CGPoint(x: 0.71201*width, y: 0.76812*height))
        path.addCurve(to: CGPoint(x: 0.70515*width, y: 0.75089*height), control1: CGPoint(x: 0.70967*width, y: 0.75962*height), control2: CGPoint(x: 0.70702*width, y: 0.75384*height))
        path.addCurve(to: CGPoint(x: 0.6975*width, y: 0.74168*height), control1: CGPoint(x: 0.70312*width, y: 0.74793*height), control2: CGPoint(x: 0.69969*width, y: 0.7438*height))
        path.addCurve(to: CGPoint(x: 0.68643*width, y: 0.73436*height), control1: CGPoint(x: 0.69532*width, y: 0.73943*height), control2: CGPoint(x: 0.69033*width, y: 0.73613*height))
        path.addCurve(to: CGPoint(x: 0.67083*width, y: 0.72916*height), control1: CGPoint(x: 0.68253*width, y: 0.73247*height), control2: CGPoint(x: 0.67551*width, y: 0.73022*height))
        path.addCurve(to: CGPoint(x: 0.65133*width, y: 0.72739*height), control1: CGPoint(x: 0.66615*width, y: 0.7281*height), control2: CGPoint(x: 0.65741*width, y: 0.72727*height))
        path.addCurve(to: CGPoint(x: 0.63417*width, y: 0.72893*height), control1: CGPoint(x: 0.64524*width, y: 0.72739*height), control2: CGPoint(x: 0.6376*width, y: 0.7281*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.15164*width, y: 0.07816*height))
        path.addCurve(to: CGPoint(x: 0.14961*width, y: 0.13129*height), control1: CGPoint(x: 0.1507*width, y: 0.0791*height), control2: CGPoint(x: 0.14992*width, y: 0.09894*height))
        path.addCurve(to: CGPoint(x: 0.15101*width, y: 0.18442*height), control1: CGPoint(x: 0.14914*width, y: 0.17249*height), control2: CGPoint(x: 0.14945*width, y: 0.18323*height))
        path.addCurve(to: CGPoint(x: 0.18612*width, y: 0.1863*height), control1: CGPoint(x: 0.15257*width, y: 0.1856*height), control2: CGPoint(x: 0.16162*width, y: 0.18607*height))
        path.addCurve(to: CGPoint(x: 0.22231*width, y: 0.18489*height), control1: CGPoint(x: 0.21326*width, y: 0.18654*height), control2: CGPoint(x: 0.21981*width, y: 0.1863*height))
        path.addCurve(to: CGPoint(x: 0.2248*width, y: 0.13081*height), control1: CGPoint(x: 0.22543*width, y: 0.18323*height), control2: CGPoint(x: 0.22543*width, y: 0.18205*height))
        path.addCurve(to: CGPoint(x: 0.22246*width, y: 0.07769*height), control1: CGPoint(x: 0.22449*width, y: 0.09386*height), control2: CGPoint(x: 0.22371*width, y: 0.07828*height))
        path.addCurve(to: CGPoint(x: 0.18705*width, y: 0.07674*height), control1: CGPoint(x: 0.22153*width, y: 0.07721*height), control2: CGPoint(x: 0.20562*width, y: 0.07674*height))
        path.addCurve(to: CGPoint(x: 0.15164*width, y: 0.07816*height), control1: CGPoint(x: 0.16178*width, y: 0.07674*height), control2: CGPoint(x: 0.15289*width, y: 0.0771*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.31825*width, y: 0.07816*height))
        path.addCurve(to: CGPoint(x: 0.31638*width, y: 0.13129*height), control1: CGPoint(x: 0.31638*width, y: 0.07934*height), control2: CGPoint(x: 0.31607*width, y: 0.08819*height))
        path.addLine(to: CGPoint(x: 0.31669*width, y: 0.183*height))
        path.addCurve(to: CGPoint(x: 0.35491*width, y: 0.18654*height), control1: CGPoint(x: 0.32309*width, y: 0.18619*height), control2: CGPoint(x: 0.32964*width, y: 0.18654*height))
        path.addCurve(to: CGPoint(x: 0.38924*width, y: 0.18489*height), control1: CGPoint(x: 0.37956*width, y: 0.18654*height), control2: CGPoint(x: 0.38674*width, y: 0.18619*height))
        path.addCurve(to: CGPoint(x: 0.39189*width, y: 0.1314*height), control1: CGPoint(x: 0.39236*width, y: 0.18323*height), control2: CGPoint(x: 0.39236*width, y: 0.18205*height))
        path.addCurve(to: CGPoint(x: 0.38877*width, y: 0.07816*height), control1: CGPoint(x: 0.39142*width, y: 0.08465*height), control2: CGPoint(x: 0.39111*width, y: 0.07957*height))
        path.addCurve(to: CGPoint(x: 0.3532*width, y: 0.07674*height), control1: CGPoint(x: 0.38674*width, y: 0.0771*height), control2: CGPoint(x: 0.37738*width, y: 0.07674*height))
        path.addCurve(to: CGPoint(x: 0.31825*width, y: 0.07816*height), control1: CGPoint(x: 0.32995*width, y: 0.07674*height), control2: CGPoint(x: 0.31981*width, y: 0.07721*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.4858*width, y: 0.07769*height))
        path.addCurve(to: CGPoint(x: 0.48362*width, y: 0.12869*height), control1: CGPoint(x: 0.48456*width, y: 0.07828*height), control2: CGPoint(x: 0.48393*width, y: 0.09303*height))
        path.addCurve(to: CGPoint(x: 0.48331*width, y: 0.18146*height), control1: CGPoint(x: 0.48331*width, y: 0.15632*height), control2: CGPoint(x: 0.48331*width, y: 0.18005*height))
        path.addCurve(to: CGPoint(x: 0.48861*width, y: 0.18536*height), control1: CGPoint(x: 0.48362*width, y: 0.18347*height), control2: CGPoint(x: 0.48502*width, y: 0.18453*height))
        path.addCurve(to: CGPoint(x: 0.52371*width, y: 0.18654*height), control1: CGPoint(x: 0.49142*width, y: 0.18607*height), control2: CGPoint(x: 0.50733*width, y: 0.18654*height))
        path.addCurve(to: CGPoint(x: 0.55725*width, y: 0.18383*height), control1: CGPoint(x: 0.55289*width, y: 0.18654*height), control2: CGPoint(x: 0.55398*width, y: 0.18642*height))
        path.addLine(to: CGPoint(x: 0.56069*width, y: 0.18123*height))
        path.addCurve(to: CGPoint(x: 0.55647*width, y: 0.07769*height), control1: CGPoint(x: 0.55866*width, y: 0.0915*height), control2: CGPoint(x: 0.55788*width, y: 0.07828*height))
        path.addCurve(to: CGPoint(x: 0.52106*width, y: 0.07674*height), control1: CGPoint(x: 0.55538*width, y: 0.07721*height), control2: CGPoint(x: 0.53947*width, y: 0.07674*height))
        path.addCurve(to: CGPoint(x: 0.4858*width, y: 0.07769*height), control1: CGPoint(x: 0.50265*width, y: 0.07674*height), control2: CGPoint(x: 0.48674*width, y: 0.07721*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.65195*width, y: 0.07898*height))
        path.addCurve(to: CGPoint(x: 0.65039*width, y: 0.13129*height), control1: CGPoint(x: 0.65086*width, y: 0.08064*height), control2: CGPoint(x: 0.65023*width, y: 0.09646*height))
        path.addCurve(to: CGPoint(x: 0.65273*width, y: 0.18359*height), control1: CGPoint(x: 0.65055*width, y: 0.17273*height), control2: CGPoint(x: 0.65086*width, y: 0.18158*height))
        path.addCurve(to: CGPoint(x: 0.68955*width, y: 0.18595*height), control1: CGPoint(x: 0.65491*width, y: 0.18583*height), control2: CGPoint(x: 0.65679*width, y: 0.18595*height))
        path.addCurve(to: CGPoint(x: 0.72543*width, y: 0.18418*height), control1: CGPoint(x: 0.71841*width, y: 0.18595*height), control2: CGPoint(x: 0.72418*width, y: 0.18571*height))
        path.addCurve(to: CGPoint(x: 0.72699*width, y: 0.1307*height), control1: CGPoint(x: 0.72637*width, y: 0.18312*height), control2: CGPoint(x: 0.72699*width, y: 0.16127*height))
        path.addCurve(to: CGPoint(x: 0.72387*width, y: 0.07792*height), control1: CGPoint(x: 0.72699*width, y: 0.08028*height), control2: CGPoint(x: 0.72699*width, y: 0.0791*height))
        path.addCurve(to: CGPoint(x: 0.68721*width, y: 0.07674*height), control1: CGPoint(x: 0.72215*width, y: 0.07721*height), control2: CGPoint(x: 0.7064*width, y: 0.07674*height))
        path.addCurve(to: CGPoint(x: 0.65195*width, y: 0.07898*height), control1: CGPoint(x: 0.65585*width, y: 0.07674*height), control2: CGPoint(x: 0.65367*width, y: 0.07686*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.46864*width, y: 0.25348*height))
        path.addCurve(to: CGPoint(x: 0.47192*width, y: 0.26682*height), control1: CGPoint(x: 0.46911*width, y: 0.25466*height), control2: CGPoint(x: 0.47051*width, y: 0.26068*height))
        path.addCurve(to: CGPoint(x: 0.47426*width, y: 0.29044*height), control1: CGPoint(x: 0.47317*width, y: 0.27296*height), control2: CGPoint(x: 0.47426*width, y: 0.28359*height))
        path.addCurve(to: CGPoint(x: 0.47098*width, y: 0.31287*height), control1: CGPoint(x: 0.47426*width, y: 0.29917*height), control2: CGPoint(x: 0.47332*width, y: 0.30579*height))
        path.addCurve(to: CGPoint(x: 0.46193*width, y: 0.33235*height), control1: CGPoint(x: 0.46911*width, y: 0.31842*height), control2: CGPoint(x: 0.46505*width, y: 0.32715*height))
        path.addCurve(to: CGPoint(x: 0.44665*width, y: 0.35242*height), control1: CGPoint(x: 0.45881*width, y: 0.33754*height), control2: CGPoint(x: 0.45179*width, y: 0.34652*height))
        path.addCurve(to: CGPoint(x: 0.40546*width, y: 0.39079*height), control1: CGPoint(x: 0.44134*width, y: 0.35821*height), control2: CGPoint(x: 0.42278*width, y: 0.37556*height))
        path.addCurve(to: CGPoint(x: 0.36459*width, y: 0.42739*height), control1: CGPoint(x: 0.38814*width, y: 0.40602*height), control2: CGPoint(x: 0.36973*width, y: 0.42255*height))
        path.addCurve(to: CGPoint(x: 0.3454*width, y: 0.44746*height), control1: CGPoint(x: 0.35944*width, y: 0.43223*height), control2: CGPoint(x: 0.3507*width, y: 0.44132*height))
        path.addCurve(to: CGPoint(x: 0.32855*width, y: 0.46989*height), control1: CGPoint(x: 0.34009*width, y: 0.4536*height), control2: CGPoint(x: 0.33245*width, y: 0.46375*height))
        path.addCurve(to: CGPoint(x: 0.31778*width, y: 0.49233*height), control1: CGPoint(x: 0.32465*width, y: 0.47603*height), control2: CGPoint(x: 0.31981*width, y: 0.48619*height))
        path.addCurve(to: CGPoint(x: 0.31295*width, y: 0.51358*height), control1: CGPoint(x: 0.3156*width, y: 0.49847*height), control2: CGPoint(x: 0.31342*width, y: 0.50803*height))
        path.addCurve(to: CGPoint(x: 0.31357*width, y: 0.53483*height), control1: CGPoint(x: 0.31232*width, y: 0.51936*height), control2: CGPoint(x: 0.31264*width, y: 0.52834*height))
        path.addCurve(to: CGPoint(x: 0.31934*width, y: 0.55608*height), control1: CGPoint(x: 0.31466*width, y: 0.54097*height), control2: CGPoint(x: 0.31716*width, y: 0.55053*height))
        path.addCurve(to: CGPoint(x: 0.33058*width, y: 0.57792*height), control1: CGPoint(x: 0.32137*width, y: 0.56163*height), control2: CGPoint(x: 0.32652*width, y: 0.57143*height))
        path.addCurve(to: CGPoint(x: 0.34743*width, y: 0.59917*height), control1: CGPoint(x: 0.33479*width, y: 0.58442*height), control2: CGPoint(x: 0.34228*width, y: 0.59398*height))
        path.addCurve(to: CGPoint(x: 0.36677*width, y: 0.61547*height), control1: CGPoint(x: 0.35257*width, y: 0.60437*height), control2: CGPoint(x: 0.36131*width, y: 0.61169*height))
        path.addCurve(to: CGPoint(x: 0.3869*width, y: 0.62739*height), control1: CGPoint(x: 0.37223*width, y: 0.61924*height), control2: CGPoint(x: 0.38128*width, y: 0.62468*height))
        path.addCurve(to: CGPoint(x: 0.41966*width, y: 0.64144*height), control1: CGPoint(x: 0.39251*width, y: 0.63022*height), control2: CGPoint(x: 0.40718*width, y: 0.6366*height))
        path.addCurve(to: CGPoint(x: 0.4532*width, y: 0.65301*height), control1: CGPoint(x: 0.43214*width, y: 0.64628*height), control2: CGPoint(x: 0.44711*width, y: 0.65148*height))
        path.addCurve(to: CGPoint(x: 0.4883*width, y: 0.6562*height), control1: CGPoint(x: 0.46178*width, y: 0.65502*height), control2: CGPoint(x: 0.46911*width, y: 0.65573*height))
        path.addCurve(to: CGPoint(x: 0.52839*width, y: 0.65478*height), control1: CGPoint(x: 0.50608*width, y: 0.65655*height), control2: CGPoint(x: 0.51669*width, y: 0.6562*height))
        path.addCurve(to: CGPoint(x: 0.55959*width, y: 0.64923*height), control1: CGPoint(x: 0.53729*width, y: 0.65372*height), control2: CGPoint(x: 0.55133*width, y: 0.65124*height))
        path.addCurve(to: CGPoint(x: 0.58502*width, y: 0.64168*height), control1: CGPoint(x: 0.56802*width, y: 0.64723*height), control2: CGPoint(x: 0.57941*width, y: 0.6438*height))
        path.addCurve(to: CGPoint(x: 0.60998*width, y: 0.63034*height), control1: CGPoint(x: 0.59064*width, y: 0.63955*height), control2: CGPoint(x: 0.60187*width, y: 0.63447*height))
        path.addCurve(to: CGPoint(x: 0.63448*width, y: 0.61535*height), control1: CGPoint(x: 0.6181*width, y: 0.62621*height), control2: CGPoint(x: 0.62917*width, y: 0.61948*height))
        path.addCurve(to: CGPoint(x: 0.65382*width, y: 0.59823*height), control1: CGPoint(x: 0.63994*width, y: 0.61133*height), control2: CGPoint(x: 0.64867*width, y: 0.60366*height))
        path.addCurve(to: CGPoint(x: 0.66942*width, y: 0.57934*height), control1: CGPoint(x: 0.65913*width, y: 0.59292*height), control2: CGPoint(x: 0.66615*width, y: 0.58442*height))
        path.addCurve(to: CGPoint(x: 0.68019*width, y: 0.55986*height), control1: CGPoint(x: 0.67285*width, y: 0.57438*height), control2: CGPoint(x: 0.67754*width, y: 0.56564*height))
        path.addCurve(to: CGPoint(x: 0.68721*width, y: 0.53896*height), control1: CGPoint(x: 0.68268*width, y: 0.55419*height), control2: CGPoint(x: 0.6858*width, y: 0.54475*height))
        path.addCurve(to: CGPoint(x: 0.68955*width, y: 0.51476*height), control1: CGPoint(x: 0.68846*width, y: 0.53306*height), control2: CGPoint(x: 0.68955*width, y: 0.5222*height))
        path.addCurve(to: CGPoint(x: 0.68721*width, y: 0.48996*height), control1: CGPoint(x: 0.68955*width, y: 0.50732*height), control2: CGPoint(x: 0.68846*width, y: 0.4961*height))
        path.addCurve(to: CGPoint(x: 0.67956*width, y: 0.46458*height), control1: CGPoint(x: 0.68596*width, y: 0.48383*height), control2: CGPoint(x: 0.68253*width, y: 0.47237*height))
        path.addCurve(to: CGPoint(x: 0.66927*width, y: 0.44156*height), control1: CGPoint(x: 0.6766*width, y: 0.45679*height), control2: CGPoint(x: 0.67192*width, y: 0.4464*height))
        path.addCurve(to: CGPoint(x: 0.65741*width, y: 0.42562*height), control1: CGPoint(x: 0.66661*width, y: 0.43672*height), control2: CGPoint(x: 0.66131*width, y: 0.42952*height))
        path.addLine(to: CGPoint(x: 0.65055*width, y: 0.41854*height))
        path.addCurve(to: CGPoint(x: 0.64041*width, y: 0.43684*height), control1: CGPoint(x: 0.64758*width, y: 0.42491*height), control2: CGPoint(x: 0.64384*width, y: 0.43129*height))
        path.addCurve(to: CGPoint(x: 0.62902*width, y: 0.45006*height), control1: CGPoint(x: 0.63682*width, y: 0.44238*height), control2: CGPoint(x: 0.63167*width, y: 0.44829*height))
        path.addCurve(to: CGPoint(x: 0.6181*width, y: 0.45407*height), control1: CGPoint(x: 0.62621*width, y: 0.45195*height), control2: CGPoint(x: 0.62137*width, y: 0.45372*height))
        path.addCurve(to: CGPoint(x: 0.60359*width, y: 0.45443*height), control1: CGPoint(x: 0.61498*width, y: 0.45455*height), control2: CGPoint(x: 0.60842*width, y: 0.45466*height))
        path.addCurve(to: CGPoint(x: 0.59126*width, y: 0.45159*height), control1: CGPoint(x: 0.59766*width, y: 0.45407*height), control2: CGPoint(x: 0.5936*width, y: 0.45325*height))
        path.addCurve(to: CGPoint(x: 0.5844*width, y: 0.44392*height), control1: CGPoint(x: 0.58924*width, y: 0.4503*height), control2: CGPoint(x: 0.58627*width, y: 0.44687*height))
        path.addCurve(to: CGPoint(x: 0.58019*width, y: 0.40142*height), control1: CGPoint(x: 0.58144*width, y: 0.43908*height), control2: CGPoint(x: 0.58112*width, y: 0.43566*height))
        path.addCurve(to: CGPoint(x: 0.57582*width, y: 0.35301*height), control1: CGPoint(x: 0.57941*width, y: 0.36883*height), control2: CGPoint(x: 0.57878*width, y: 0.36281*height))
        path.addCurve(to: CGPoint(x: 0.56677*width, y: 0.33176*height), control1: CGPoint(x: 0.57395*width, y: 0.34687*height), control2: CGPoint(x: 0.56989*width, y: 0.33731*height))
        path.addCurve(to: CGPoint(x: 0.55741*width, y: 0.31582*height), control1: CGPoint(x: 0.56381*width, y: 0.32621*height), control2: CGPoint(x: 0.55959*width, y: 0.31901*height))
        path.addCurve(to: CGPoint(x: 0.54602*width, y: 0.30224*height), control1: CGPoint(x: 0.55523*width, y: 0.31251*height), control2: CGPoint(x: 0.55008*width, y: 0.30649*height))
        path.addCurve(to: CGPoint(x: 0.52075*width, y: 0.28158*height), control1: CGPoint(x: 0.54197*width, y: 0.29799*height), control2: CGPoint(x: 0.53058*width, y: 0.28867*height))
        path.addCurve(to: CGPoint(x: 0.4961*width, y: 0.26423*height), control1: CGPoint(x: 0.51108*width, y: 0.27438*height), control2: CGPoint(x: 0.5*width, y: 0.26659*height))
        path.addCurve(to: CGPoint(x: 0.47972*width, y: 0.25573*height), control1: CGPoint(x: 0.4922*width, y: 0.26187*height), control2: CGPoint(x: 0.48487*width, y: 0.25797*height))
        path.addCurve(to: CGPoint(x: 0.46911*width, y: 0.25148*height), control1: CGPoint(x: 0.47457*width, y: 0.25336*height), control2: CGPoint(x: 0.46973*width, y: 0.25148*height))
        path.addCurve(to: CGPoint(x: 0.46864*width, y: 0.25348*height), control1: CGPoint(x: 0.46833*width, y: 0.25148*height), control2: CGPoint(x: 0.46817*width, y: 0.25242*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.52995*width, y: 0.41653*height))
        path.addCurve(to: CGPoint(x: 0.47332*width, y: 0.47226*height), control1: CGPoint(x: 0.52075*width, y: 0.42479*height), control2: CGPoint(x: 0.49532*width, y: 0.44982*height))
        path.addCurve(to: CGPoint(x: 0.42402*width, y: 0.52361*height), control1: CGPoint(x: 0.45133*width, y: 0.49469*height), control2: CGPoint(x: 0.42917*width, y: 0.51771*height))
        path.addCurve(to: CGPoint(x: 0.41498*width, y: 0.53625*height), control1: CGPoint(x: 0.41903*width, y: 0.5294*height), control2: CGPoint(x: 0.41482*width, y: 0.53518*height))
        path.addCurve(to: CGPoint(x: 0.4209*width, y: 0.53943*height), control1: CGPoint(x: 0.41498*width, y: 0.53766*height), control2: CGPoint(x: 0.41695*width, y: 0.53872*height))
        path.addCurve(to: CGPoint(x: 0.45008*width, y: 0.54144*height), control1: CGPoint(x: 0.42402*width, y: 0.54014*height), control2: CGPoint(x: 0.43729*width, y: 0.54097*height))
        path.addCurve(to: CGPoint(x: 0.47629*width, y: 0.54321*height), control1: CGPoint(x: 0.46303*width, y: 0.54191*height), control2: CGPoint(x: 0.47473*width, y: 0.54274*height))
        path.addCurve(to: CGPoint(x: 0.47894*width, y: 0.55018*height), control1: CGPoint(x: 0.47832*width, y: 0.54404*height), control2: CGPoint(x: 0.47894*width, y: 0.54569*height))
        path.addCurve(to: CGPoint(x: 0.46552*width, y: 0.59469*height), control1: CGPoint(x: 0.47894*width, y: 0.55384*height), control2: CGPoint(x: 0.47379*width, y: 0.57107*height))
        path.addCurve(to: CGPoint(x: 0.45273*width, y: 0.63447*height), control1: CGPoint(x: 0.45819*width, y: 0.61606*height), control2: CGPoint(x: 0.45242*width, y: 0.63388*height))
        path.addCurve(to: CGPoint(x: 0.46412*width, y: 0.6268*height), control1: CGPoint(x: 0.45304*width, y: 0.63495*height), control2: CGPoint(x: 0.45803*width, y: 0.63152*height))
        path.addCurve(to: CGPoint(x: 0.50546*width, y: 0.58973*height), control1: CGPoint(x: 0.4702*width, y: 0.62196*height), control2: CGPoint(x: 0.48877*width, y: 0.60531*height))
        path.addCurve(to: CGPoint(x: 0.55226*width, y: 0.54569*height), control1: CGPoint(x: 0.52231*width, y: 0.57414*height), control2: CGPoint(x: 0.54337*width, y: 0.55431*height))
        path.addCurve(to: CGPoint(x: 0.57676*width, y: 0.5209*height), control1: CGPoint(x: 0.56131*width, y: 0.53707*height), control2: CGPoint(x: 0.57223*width, y: 0.52597*height))
        path.addCurve(to: CGPoint(x: 0.58378*width, y: 0.51015*height), control1: CGPoint(x: 0.58144*width, y: 0.51547*height), control2: CGPoint(x: 0.58424*width, y: 0.5111*height))
        path.addCurve(to: CGPoint(x: 0.57956*width, y: 0.50756*height), control1: CGPoint(x: 0.58315*width, y: 0.50921*height), control2: CGPoint(x: 0.58128*width, y: 0.50815*height))
        path.addCurve(to: CGPoint(x: 0.5546*width, y: 0.5059*height), control1: CGPoint(x: 0.57785*width, y: 0.50708*height), control2: CGPoint(x: 0.56661*width, y: 0.50638*height))
        path.addCurve(to: CGPoint(x: 0.5273*width, y: 0.50413*height), control1: CGPoint(x: 0.54259*width, y: 0.50543*height), control2: CGPoint(x: 0.53027*width, y: 0.5046*height))
        path.addCurve(to: CGPoint(x: 0.5195*width, y: 0.50106*height), control1: CGPoint(x: 0.52434*width, y: 0.50354*height), control2: CGPoint(x: 0.52075*width, y: 0.50224*height))
        path.addCurve(to: CGPoint(x: 0.51747*width, y: 0.49421*height), control1: CGPoint(x: 0.5181*width, y: 0.49988*height), control2: CGPoint(x: 0.51732*width, y: 0.49717*height))
        path.addCurve(to: CGPoint(x: 0.52512*width, y: 0.46989*height), control1: CGPoint(x: 0.51778*width, y: 0.4915*height), control2: CGPoint(x: 0.52106*width, y: 0.48064*height))
        path.addCurve(to: CGPoint(x: 0.53822*width, y: 0.43447*height), control1: CGPoint(x: 0.52902*width, y: 0.45915*height), control2: CGPoint(x: 0.53495*width, y: 0.44321*height))
        path.addCurve(to: CGPoint(x: 0.54602*width, y: 0.41145*height), control1: CGPoint(x: 0.5415*width, y: 0.42574*height), control2: CGPoint(x: 0.54493*width, y: 0.41535*height))
        path.addCurve(to: CGPoint(x: 0.54727*width, y: 0.40295*height), control1: CGPoint(x: 0.54711*width, y: 0.40756*height), control2: CGPoint(x: 0.54758*width, y: 0.40378*height))
        path.addCurve(to: CGPoint(x: 0.52995*width, y: 0.41653*height), control1: CGPoint(x: 0.5468*width, y: 0.40213*height), control2: CGPoint(x: 0.539*width, y: 0.40826*height))
        path.closeSubpath()
        return path
    }
}


struct IconView: View {
    var color: Color = .black
    var fillStyle: FillStyle = FillStyle(eoFill: true)

    var body: some View {
        IconShape().fill(color, style: fillStyle)
    }
}



// MARK: - Preview
#Preview("SwiftFlash Logo - Different Sizes") {
    VStack(spacing: 20) {
        Text("SwiftFlash Vector Logo Preview")
            .font(.title)
            .padding()
        
        // Large size (About dialog)
        VStack {
            Text("Large ")
                .font(.caption)
            IconView(color: .black)
        }

    }
    .padding()
    .background(Color(.windowBackgroundColor))
    .frame(width: 500, height: 500)
}

#Preview("SwiftFlash Logo - Color Variations") {
    VStack(spacing: 20) {
        Text("Color Variations")
            .font(.title)
            .padding()
        
        HStack(spacing: 20) {
            // Blue gradient (current)
            VStack {
                Text("Blue Gradient")
                    .font(.caption)
                IconView(color: .black)
                IconShape()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: FillStyle(eoFill: true)
                    )
                    .aspectRatio(641.0/847.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // White fill
            VStack {
                Text("White Fill")
                    .font(.caption)
                IconShape()
                    .fill(Color.white, style: FillStyle(eoFill: true))
                    .aspectRatio(641.0/847.0, contentMode: .fit)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // System blue
            VStack {
                Text("System Blue")
                    .font(.caption)
                IconView(color: .accentColor)
            }
        }
        
        HStack(spacing: 20) {
            // Gray
            VStack {
                Text("Gray")
                    .font(.caption)
                IconView(color: .gray)
            }
            
            // Black
            VStack {
                Text("Black")
                    .font(.caption)
                IconView()
            }
            
            // Custom gradient
            VStack {
                Text("Custom Gradient")
                    .font(.caption)
                
                IconShape()
                    .fill(LinearGradient(
                        colors: [Color.orange, Color.red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing), style: FillStyle(eoFill: true))
                    .aspectRatio(641.0/847.0, contentMode: .fit)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    .padding()
    .background(Color(.windowBackgroundColor))
}
